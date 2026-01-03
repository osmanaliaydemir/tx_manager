using TX_Manager.Application.Common.Models;

namespace TX_Manager.Application.Common.Interfaces;

public interface IXApiService
{
    // OAuth PKCE flow methods
    string GetAuthorizationUrl();
    
    // Updated to include state for PKCE verification
    Task<XAuthResult> ExchangeCodeForTokenAsync(string code, string state); 
    
    // Posting to X
    Task<string> PostTweetAsync(string accessToken, string content);
    Task<XUserProfile> GetMyUserProfileAsync(string accessToken);
    
    // Refresh Token
    Task<XAuthResult> RefreshTokenAsync(string refreshToken);
}

public class XUserProfile
{
    public string Id { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}
