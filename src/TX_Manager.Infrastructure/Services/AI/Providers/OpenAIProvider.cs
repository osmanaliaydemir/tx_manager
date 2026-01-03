using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Interfaces;

namespace TX_Manager.Infrastructure.Services.AI.Providers;

public class OpenAIProvider : ILanguageModelProvider
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly string _model;
    private readonly ILogger<OpenAIProvider> _logger;

    public OpenAIProvider(HttpClient httpClient, IConfiguration configuration, ILogger<OpenAIProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _apiKey = configuration["AI:OpenAI:ApiKey"] ?? "";
        _model = configuration["AI:OpenAI:Model"] ?? "gpt-4o-mini";
    }

    public async Task<string> GenerateTextAsync(string prompt, string systemInstruction = "")
    {
        if (string.IsNullOrEmpty(_apiKey)) throw new Exception("OpenAI API Key is missing");

        var requestBody = new
        {
            model = _model,
            messages = new[]
            {
                new { role = "system", content = systemInstruction },
                new { role = "user", content = prompt }
            },
            temperature = 0.7
        };

        var content = new StringContent( JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");
        
        var request = new HttpRequestMessage(HttpMethod.Post, "https://api.openai.com/v1/chat/completions");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
        request.Content = content;

        var response = await _httpClient.SendAsync(request);
        var responseString = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("OpenAI API Failed: {Error}", responseString);
            throw new Exception($"OpenAI Error: {response.StatusCode}");
        }

        using var doc = JsonDocument.Parse(responseString);
        var result = doc.RootElement
            .GetProperty("choices")[0]
            .GetProperty("message")
            .GetProperty("content")
            .GetString();

        return result ?? "";
    }
}
