using System;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Infrastructure.Services.AI.Providers;

namespace TX_Manager.Infrastructure.Services.AI;

public static class AIFactory
{
    public static ILanguageModelProvider Create(IServiceProvider serviceProvider)
    {
        var configuration = serviceProvider.GetRequiredService<IConfiguration>();
        var providerType = configuration["AI:ActiveProvider"] ?? "Mock";

        return providerType switch
        {
            "OpenAI" => serviceProvider.GetRequiredService<OpenAIProvider>(),
            "Gemini" => serviceProvider.GetRequiredService<GeminiProvider>(),
            "Mock" => serviceProvider.GetRequiredService<MockAIProvider>(),
            _ => serviceProvider.GetRequiredService<MockAIProvider>()
        };
    }
}
