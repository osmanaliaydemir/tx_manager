using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Interfaces;

namespace TX_Manager.Infrastructure.Services.AI.Providers;

public class GeminiProvider : ILanguageModelProvider
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly string _model; // e.g., "gemini-1.5-flash"
    private readonly ILogger<GeminiProvider> _logger;

    public GeminiProvider(HttpClient httpClient, IConfiguration configuration, ILogger<GeminiProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _apiKey = configuration["AI:Gemini:ApiKey"] ?? "";
        _model = configuration["AI:Gemini:Model"] ?? "gemini-1.5-flash";
    }

    public async Task<string> GenerateTextAsync(string prompt, string systemInstruction = "")
    {
        if (string.IsNullOrEmpty(_apiKey)) throw new Exception("Gemini API Key is missing");

        // Gemini API URL
        var url = $"https://generativelanguage.googleapis.com/v1beta/models/{_model}:generateContent?key={_apiKey}";

        // Combine system instruction and prompt for simple Gemini GenerateContent Call
        // Or use system_instruction property if supported by specific model version, 
        // but concatenating is safer for general use cases in v1beta.
        var fullPrompt = $"{systemInstruction}\n\nUSER REQUEST: {prompt}";

        var requestBody = new
        {
            contents = new[]
            {
                new { parts = new[] { new { text = fullPrompt } } }
            }
        };

        var content = new StringContent( JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");
        
        var response = await _httpClient.PostAsync(url, content);
        var responseString = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("Gemini API Failed: {Error}", responseString);
            throw new Exception($"Gemini Error: {response.StatusCode}");
        }

        using var doc = JsonDocument.Parse(responseString);
        try
        {
            var result = doc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString();
            return result ?? "";
        }
        catch (Exception)
        {
             _logger.LogError("Gemini Parse Failed. Raw: {Raw}", responseString);
             throw new Exception("Failed to parse Gemini response");
        }
    }
}
