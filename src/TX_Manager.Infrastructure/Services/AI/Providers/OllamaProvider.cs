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

public class OllamaProvider : ILanguageModelProvider
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    private readonly string _model;
    private readonly ILogger<OllamaProvider> _logger;

    public OllamaProvider(HttpClient httpClient, IConfiguration configuration, ILogger<OllamaProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        // Default to localhost Ollama OpenAI compatible endpoint
        _baseUrl = configuration["AI:Ollama:BaseUrl"] ?? "http://localhost:11434/v1/chat/completions";
        _model = configuration["AI:Ollama:Model"] ?? "llama3";
    }

    public async Task<string> GenerateTextAsync(string prompt, string systemInstruction = "")
    {
        _logger.LogInformation("Sending request to Local Ollama: {Url} Model: {Model}", _baseUrl, _model);

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

        var content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");
        
        var request = new HttpRequestMessage(HttpMethod.Post, _baseUrl);
        // Ollama usually doesn't strictly require API key, but 'ollama' is convention for some clients
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", "ollama");
        request.Content = content;

        try 
        {
            var response = await _httpClient.SendAsync(request);
            var responseString = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Ollama API Failed: {Error}", responseString);
                throw new Exception($"Ollama Error: {response.StatusCode} - {responseString}");
            }

            using var doc = JsonDocument.Parse(responseString);
            var result = doc.RootElement
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString();

            return result ?? "";
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Could not connect to Ollama. Make sure it is running locally.");
            throw new Exception("Local AI connection failed. Is Ollama running? (ollama serve)");
        }
    }
}
