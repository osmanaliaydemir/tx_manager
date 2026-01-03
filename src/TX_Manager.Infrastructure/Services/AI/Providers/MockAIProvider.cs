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
        var mockJson = @"[
    {
        ""text"": ""Güne enerjik başla! Bugün hedeflerine bir adım daha yaklaşmak için harika bir fırsat. 🚀 #Motivasyon #Başarı"",
        ""rationale"": ""Bu tweet, takipçilerinize pozitif enerji vererek etkileşimi artırmayı hedefler.""
    },
    {
        ""text"": ""Bazen durup nefes almak, ilerlemek kadar önemlidir. Kendine vakit ayırmayı unutma. 🌿 #KişiselGelişim"",
        ""rationale"": ""Denge ve huzur temalı bu tweet, kullanıcılarla samimi bir bağ kurar.""
    },
    {
        ""text"": ""Yapay Zeka geleceği şekillendiriyor, peki sen buna hazır mısın? Öğrenmeye bugün başla! 🤖 #AI #Teknoloji"",
        ""rationale"": ""Teknoloji meraklısı kitleniz için güncel ve ilgi çekici bir soru.""
    }
]";
        return Task.FromResult(mockJson);
    }
}
