using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;
using TX_Manager.Application.Services;

namespace TX_Manager.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());
        
        // Mapster is generally static but we can add ITypeAdapterConfig
        // Config Mapster if needed
        // TypeAdapterConfig.GlobalSettings.Scan(Assembly.GetExecutingAssembly());

        services.AddTransient<IPostService, PostService>();
        services.AddTransient<IAnalyticsService, AnalyticsService>();
        
        return services;
    }
}
