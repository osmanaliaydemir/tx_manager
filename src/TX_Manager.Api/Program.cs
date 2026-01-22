using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using System.Text;
using TX_Manager.Api.Auth;
using TX_Manager.Api.Hangfire;
using TX_Manager.Api.Observability;
using TX_Manager.Api.Middleware;
using TX_Manager.Application;
using TX_Manager.Application.Common.Time;
using TX_Manager.Application.Common.Observability;
using TX_Manager.Application.Services;
using TX_Manager.Infrastructure;
using TX_Manager.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

// 1. Serilog Setup
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateLogger();

builder.Host.UseSerilog();

// 2. Add Services
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton<IJobRunStore, InMemoryJobRunStore>();
builder.Services.Configure<AutoScheduleOptions>(builder.Configuration.GetSection("Scheduling:AutoSchedule"));

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();

var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = true;
        options.SaveToken = true;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// Best-effort auto-migrate in Development (and optionally via config).
// This prevents runtime failures like "Invalid object name 'IdempotencyRecords'".
var autoMigrate = app.Environment.IsDevelopment() ||
                  builder.Configuration.GetValue<bool>("Database:AutoMigrate");
if (autoMigrate)
{
    try
    {
        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.Migrate();
    }
    catch (Exception ex)
    {
        Log.Warning(ex, "Database auto-migration failed.");
    }
}

// 3. Configure Pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseSerilogRequestLogging();
app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseMiddleware<IdempotencyMiddleware>();

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// 4. Hangfire Dashboard
app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    Authorization = new[] { new HangfireDashboardAuthFilter(app.Configuration) }
});

// 5. Schedule Recurring Jobs
{
    using var scope = app.Services.CreateScope();
    var recurringJobManager = scope.ServiceProvider.GetRequiredService<IRecurringJobManager>();
    
    // Run every minute
    recurringJobManager.AddOrUpdate<TX_Manager.Infrastructure.BackgroundJobs.PostTweetJob>(
        "publish-scheduled-posts",
        job => job.ExecuteAsync(),
        Cron.Minutely);

    // Run every hour
    recurringJobManager.AddOrUpdate<TX_Manager.Infrastructure.BackgroundJobs.AnalyticsJob>(
        "update-post-analytics",
        job => job.ExecuteAsync(),
        Cron.Hourly);
}

app.Run();
