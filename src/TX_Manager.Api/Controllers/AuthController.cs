using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Domain.Entities;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IXApiService _xApi;
    private readonly IApplicationDbContext _context;
    private readonly ITokenEncryptionService _encryption;
    private readonly IStrategyService _strategyService;

    public AuthController(
        IXApiService xApi, 
        IApplicationDbContext context,
        ITokenEncryptionService encryption,
        IStrategyService strategyService)
    {
        _xApi = xApi;
        _context = context;
        _encryption = encryption;
        _strategyService = strategyService;
    }

    [HttpGet("login")]
    public IActionResult Login()
    {
        var url = _xApi.GetAuthorizationUrl();
        return Redirect(url);
    }

    [HttpGet("callback")]
    public async Task<IActionResult> Callback(string code, string state)
    {
        if (string.IsNullOrEmpty(code)) return BadRequest("Code is missing");

        try
        {
            var authResult = await _xApi.ExchangeCodeForTokenAsync(code, state);
            
            // Get User Profile from X
            var xProfile = await _xApi.GetMyUserProfileAsync(authResult.AccessToken);
            
            // Find or Create User
            var user = await _context.Users.FirstOrDefaultAsync(u => u.XUserId == xProfile.Id);
            if (user == null)
            {
                user = new User
                {
                    XUserId = xProfile.Id,
                    Username = xProfile.Username,
                    Name = xProfile.Name,
                    ProfileImageUrl = xProfile.ProfileImageUrl
                };
                _context.Users.Add(user);
                await _context.SaveChangesAsync();
            }
            else
            {
                // Update existing user info if changed
                user.Username = xProfile.Username;
                user.Name = xProfile.Name;
                user.ProfileImageUrl = xProfile.ProfileImageUrl;
                await _context.SaveChangesAsync();
            }
            
            // Update/Create Auth Token
            var tokenEntity = await _context.AuthTokens.FirstOrDefaultAsync(t => t.UserId == user.Id);
            if (tokenEntity == null)
            {
                tokenEntity = new AuthToken { UserId = user.Id };
                _context.AuthTokens.Add(tokenEntity);
            }
            
            tokenEntity.EncryptedAccessToken = _encryption.Encrypt(authResult.AccessToken);
            tokenEntity.EncryptedRefreshToken = _encryption.Encrypt(authResult.RefreshToken ?? "");
            tokenEntity.ExpiresAt = DateTime.UtcNow.AddSeconds(authResult.ExpiresIn);
            
            await _context.SaveChangesAsync();

            // Check Strategy
            var hasStrategy = await _strategyService.HasStrategyAsync(user.Id);

            // Redirect to Deep Link / Custom Scheme for mobile to intercept
            return Redirect($"txmanager://auth-success?userId={user.Id}&hasStrategy={hasStrategy}");
        }
        catch (Exception ex)
        {
            return Redirect($"txmanager://auth-error?message={ex.Message}");
        }
    }

    [HttpGet("me/{userId}")]
    public async Task<IActionResult> GetMe(Guid userId)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        return Ok(new 
        {
            user.Id,
            user.Username,
            user.Name,
            user.ProfileImageUrl
        });
    }

    [HttpGet("status/{userId}")]
    public async Task<IActionResult> GetAuthStatus(Guid userId)
    {
        var tokenEntity = await _context.AuthTokens.FirstOrDefaultAsync(t => t.UserId == userId);
        if (tokenEntity == null)
        {
            return Ok(new
            {
                HasToken = false,
                ExpiresAtUtc = (DateTime?)null,
                IsExpired = true,
                CanRefresh = false,
                RequiresLogin = true
            });
        }

        var now = DateTime.UtcNow;
        bool isExpired = tokenEntity.ExpiresAt <= now;

        bool canRefresh = false;
        if (!string.IsNullOrWhiteSpace(tokenEntity.EncryptedRefreshToken))
        {
            try
            {
                // If decrypt works and refresh token is non-empty we assume refresh is possible
                var refreshToken = _encryption.Decrypt(tokenEntity.EncryptedRefreshToken);
                canRefresh = !string.IsNullOrWhiteSpace(refreshToken);
            }
            catch
            {
                canRefresh = false;
            }
        }

        return Ok(new
        {
            HasToken = true,
            ExpiresAtUtc = tokenEntity.ExpiresAt,
            IsExpired = isExpired,
            CanRefresh = canRefresh,
            RequiresLogin = isExpired && !canRefresh
        });
    }

    public class UpdateTimezoneRequest
    {
        public string? TimeZoneName { get; set; }
        public int? TimeZoneOffsetMinutes { get; set; }
    }

    [HttpPost("timezone/{userId}")]
    public async Task<IActionResult> UpdateTimezone(Guid userId, [FromBody] UpdateTimezoneRequest request)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        user.TimeZoneName = request.TimeZoneName;
        user.TimeZoneOffsetMinutes = request.TimeZoneOffsetMinutes;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return Ok(new { Message = "Timezone updated." });
    }
}
