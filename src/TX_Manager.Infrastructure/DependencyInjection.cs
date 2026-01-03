using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Infrastructure.Persistence;
using TX_Manager.Infrastructure.Services;
using TX_Manager.Infrastructure.Services.AI;
using TX_Manager.Infrastructure.Services.AI.Providers;
using Hangfire;
using Hangfire.SqlServer;
using System;

namespace TX_Manager.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection");

        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlServer(connectionString));

        services.AddScoped<IApplicationDbContext>(provider => provider.GetRequiredService<AppDbContext>());

        // Hangfire Setup
        services.AddHangfire(config => config
            .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
            .UseSimpleAssemblyNameTypeSerializer()
            .UseRecommendedSerializerSettings()
            .UseSqlServerStorage(connectionString, new SqlServerStorageOptions
            {
                CommandBatchMaxTimeout = TimeSpan.FromMinutes(5),
                SlidingInvisibilityTimeout = TimeSpan.FromMinutes(5),
                QueuePollInterval = TimeSpan.Zero,
                UseRecommendedIsolationLevel = true,
                DisableGlobalLocks = true
            }));

        services.AddHangfireServer();
        
        services.AddMemoryCache();
        services.AddHttpClient<IXApiService, XApiService>();

        // Services
        services.AddTransient<ITokenEncryptionService, TokenEncryptionService>();
        
        // Strategy Service
        services.AddTransient<IStrategyService, StrategyService>();
        
        // AI Services
        services.AddHttpClient<OpenAIProvider>();
        services.AddHttpClient<GeminiProvider>();
        services.AddTransient<MockAIProvider>();

        services.AddTransient<ILanguageModelProvider>(sp => AIFactory.Create(sp));
        services.AddTransient<IAIGeneratorService, AIGeneratorService>();

        return services;
    }
}
