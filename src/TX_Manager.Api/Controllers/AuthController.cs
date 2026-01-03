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
                    Username = xProfile.Username
                };
                _context.Users.Add(user);
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
}
