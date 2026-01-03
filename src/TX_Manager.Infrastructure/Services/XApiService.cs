using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.Common.Models;

namespace TX_Manager.Infrastructure.Services;

public class XApiService : IXApiService
{
    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly ILogger<XApiService> _logger;
    private readonly string _clientId;
    private readonly string _clientSecret; // For confidentiality if needed, though PKCE often for public
    private readonly string _redirectUri;
    private readonly string _scopes;

    public XApiService(
        HttpClient httpClient, 
        IConfiguration configuration,
        IMemoryCache cache,
        ILogger<XApiService> logger)
    {
        _httpClient = httpClient;
        _cache = cache;
        _logger = logger;

        var section = configuration.GetSection("Twitter");
        _clientId = section["ClientId"] ?? "";
        _clientSecret = section["ClientSecret"] ?? "";
        _redirectUri = section["RedirectUri"] ?? "";
        _scopes = section["Scopes"] ?? "tweet.read tweet.write users.read offline.access";
    }

    public string GetAuthorizationUrl()
    {
        // 1. Generate State and CodeVerifier
        var state = GenerateRandomString(32);
        var codeVerifier = GenerateRandomString(64);
        
        // 2. Cache the verifier with state as key, simplify for demo
        _cache.Set(state, codeVerifier, TimeSpan.FromMinutes(10));

        // 3. Generate Code Challenge
        var codeChallenge = ComputeCodeChallenge(codeVerifier);

        // 4. Build URL
        var url = $"https://twitter.com/i/oauth2/authorize?response_type=code&client_id={_clientId}&redirect_uri={Uri.EscapeDataString(_redirectUri)}&scope={Uri.EscapeDataString(_scopes)}&state={state}&code_challenge={codeChallenge}&code_challenge_method=S256";
        
        return url;
    }

    public async Task<XAuthResult> ExchangeCodeForTokenAsync(string code, string state)
    {
        if (!_cache.TryGetValue(state, out string? codeVerifier))
        {
            throw new InvalidOperationException("Invalid state or session expired.");
        }
        _cache.Remove(state); // Consume it

        var requestContent = new FormUrlEncodedContent(new[]
        {
            new KeyValuePair<string, string>("code", code),
            new KeyValuePair<string, string>("grant_type", "authorization_code"),
            new KeyValuePair<string, string>("client_id", _clientId),
            new KeyValuePair<string, string>("redirect_uri", _redirectUri),
            new KeyValuePair<string, string>("code_verifier", codeVerifier!)
        });
        
        var message = new HttpRequestMessage(HttpMethod.Post, "https://api.twitter.com/2/oauth2/token");
        message.Content = requestContent;
        
        if (!string.IsNullOrEmpty(_clientSecret))
        {
             var credentials = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_clientId}:{_clientSecret}"));
             message.Headers.Authorization = new AuthenticationHeaderValue("Basic", credentials);
        }

        var response = await _httpClient.SendAsync(message);
        var content = await response.Content.ReadAsStringAsync();
        
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("Token Exchange failed: {Content}", content);
            throw new Exception($"Token exchange failed: {response.StatusCode}");
        }

        var tokenResponse = System.Text.Json.JsonSerializer.Deserialize<TokenResponse>(content);
        if (tokenResponse == null) throw new Exception("Invalid token response");
        
        return new XAuthResult 
        {
            AccessToken = tokenResponse.AccessToken,
            RefreshToken = tokenResponse.RefreshToken,
            ExpiresIn = tokenResponse.ExpiresIn
        };
    }

    public async Task<XAuthResult> RefreshTokenAsync(string refreshToken)
    {
        var requestContent = new FormUrlEncodedContent(new[]
        {
            new KeyValuePair<string, string>("grant_type", "refresh_token"),
            new KeyValuePair<string, string>("refresh_token", refreshToken),
            new KeyValuePair<string, string>("client_id", _clientId),
        });

        var message = new HttpRequestMessage(HttpMethod.Post, "https://api.twitter.com/2/oauth2/token");
        message.Content = requestContent;

        // Basic Auth header might not be needed for Public Clients (PKCE), but good to be consistent
        // if Client Secret is present.
        if (!string.IsNullOrEmpty(_clientSecret))
        {
             var credentials = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_clientId}:{_clientSecret}"));
             message.Headers.Authorization = new AuthenticationHeaderValue("Basic", credentials);
        }

        var response = await _httpClient.SendAsync(message);
        var content = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("Token Refresh failed: {Content}", content);
            throw new Exception($"Token refresh failed: {response.StatusCode}");
        }

        var tokenResponse = System.Text.Json.JsonSerializer.Deserialize<TokenResponse>(content);
        if (tokenResponse == null) throw new Exception("Invalid token response");

        return new XAuthResult 
        {
            AccessToken = tokenResponse.AccessToken,
            RefreshToken = tokenResponse.RefreshToken, // X might rotate refresh tokens
            ExpiresIn = tokenResponse.ExpiresIn
        };
    }

    public async Task<string> PostTweetAsync(string accessToken, string content)
    {
        var request = new
        {
            text = content
        };

        var message = new HttpRequestMessage(HttpMethod.Post, "https://api.twitter.com/2/tweets");
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        message.Content = JsonContent.Create(request);

        var response = await _httpClient.SendAsync(message);
        var resContent = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            throw new Exception($"Tweet failed: {resContent}");
        }

        // Parse ID
        using var doc = System.Text.Json.JsonDocument.Parse(resContent);
        return doc.RootElement.GetProperty("data").GetProperty("id").GetString()!;
    }

    public async Task<XUserProfile> GetMyUserProfileAsync(string accessToken)
    {
        var message = new HttpRequestMessage(HttpMethod.Get, "https://api.twitter.com/2/users/me");
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await _httpClient.SendAsync(message);
        var content = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("User Profile Fetch failed: {Content}", content);
            throw new Exception($"User profile fetch failed: {response.StatusCode}");
        }

        // Expected JSON: { "data": { "id": "...", "name": "...", "username": "..." } }
        using var doc = System.Text.Json.JsonDocument.Parse(content);
        var data = doc.RootElement.GetProperty("data");

        return new XUserProfile
        {
            Id = data.GetProperty("id").GetString() ?? "",
            Name = data.GetProperty("name").GetString() ?? "",
            Username = data.GetProperty("username").GetString() ?? ""
        };
    }

    // Helpers
    private static string GenerateRandomString(int length)
    {
        var bytes = new byte[length];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static string ComputeCodeChallenge(string codeVerifier)
    {
        using var sha256 = SHA256.Create();
        var challengeBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(codeVerifier));
        return Convert.ToBase64String(challengeBytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }
    
    private class TokenResponse
    {
        [JsonPropertyName("access_token")]
        public string AccessToken { get; set; } = "";
        
        [JsonPropertyName("refresh_token")]
        public string RefreshToken { get; set; } = "";
        
        [JsonPropertyName("expires_in")]
        public int ExpiresIn { get; set; }
    }
}
