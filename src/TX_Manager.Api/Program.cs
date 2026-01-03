using Hangfire;
using Serilog;
using TX_Manager.Api.Middleware;
using TX_Manager.Application;
using TX_Manager.Application.Services;
using TX_Manager.Infrastructure;

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

var app = builder.Build();

// 3. Configure Pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseSerilogRequestLogging();
app.UseMiddleware<ExceptionHandlingMiddleware>();

app.UseHttpsRedirection();
app.UseAuthorization();

app.MapControllers();

// 4. Hangfire Dashboard
app.UseHangfireDashboard("/hangfire");

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
