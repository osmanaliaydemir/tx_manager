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

public class DeepSeekProvider : ILanguageModelProvider
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly string _model;
    private readonly ILogger<DeepSeekProvider> _logger;

    public DeepSeekProvider(HttpClient httpClient, IConfiguration configuration, ILogger<DeepSeekProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _apiKey = configuration["AI:DeepSeek:ApiKey"] ?? "";
        _model = configuration["AI:DeepSeek:Model"] ?? "deepseek-chat";
    }

    public async Task<string> GenerateTextAsync(string prompt, string systemInstruction = "")
    {
        if (string.IsNullOrEmpty(_apiKey)) throw new Exception("DeepSeek API Key is missing");

        var requestBody = new
        {
            model = _model,
            messages = new[]
            {
                new { role = "system", content = systemInstruction },
                new { role = "user", content = prompt }
            },
            temperature = 0.7,
            stream = false
        };

        var content = new StringContent( JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");
        
        var request = new HttpRequestMessage(HttpMethod.Post, "https://api.deepseek.com/chat/completions");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
        request.Content = content;

        var response = await _httpClient.SendAsync(request);
        var responseString = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("DeepSeek API Failed: {Error}", responseString);
            throw new Exception($"DeepSeek Error: {response.StatusCode} - {responseString}");
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
