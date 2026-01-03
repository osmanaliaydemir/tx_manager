using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Interfaces;

namespace TX_Manager.Infrastructure.Services.AI.Providers;

public class MockAIProvider : ILanguageModelProvider
{
    private readonly ILogger<MockAIProvider> _logger;

    public MockAIProvider(ILogger<MockAIProvider> logger)
    {
        _logger = logger;
    }

    public Task<string> GenerateTextAsync(string prompt, string systemInstruction = "")
    {
        _logger.LogInformation("Creating MOCK AI Response for prompt: {Prompt}", prompt);
        
        // Simulate thinking
        return Task.FromResult("Bu bir Mock AI yanıtıdır. Gerçek bir API çağrısı yapılmamıştır. " +
                               "\n\nÖrnek Tweet: Harika bir gün başlangıcı! 🚀 #Motivasyon");
    }
}
