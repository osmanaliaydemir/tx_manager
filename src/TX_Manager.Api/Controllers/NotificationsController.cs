using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TX_Manager.Api.Auth;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Domain.Entities;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly IApplicationDbContext _db;

    public NotificationsController(IApplicationDbContext db)
    {
        _db = db;
    }

    public class RegisterDeviceTokenRequest
    {
        public string Token { get; set; } = string.Empty;
        // String is intentional: mobile sends "Android"/"Ios"/"Web" and we don't rely on JsonStringEnumConverter.
        public string? Platform { get; set; }
        public string? DeviceId { get; set; }
    }

    [HttpPost("device-tokens/register")]
    public async Task<IActionResult> Register([FromBody] RegisterDeviceTokenRequest request)
    {
        var token = (request.Token ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(token)) return BadRequest("token is required");

        var userId = User.GetUserId();
        var now = DateTime.UtcNow;
        var platform = ParsePlatform(request.Platform);

        var existing = await _db.DeviceTokens
            .FirstOrDefaultAsync(d => d.UserId == userId && d.Token == token);

        if (existing == null)
        {
            var entity = new DeviceToken
            {
                UserId = userId,
                Token = token,
                Platform = platform,
                DeviceId = string.IsNullOrWhiteSpace(request.DeviceId) ? null : request.DeviceId.Trim(),
                IsActive = true,
                LastSeenAtUtc = now,
                CreatedAt = now
            };
            _db.DeviceTokens.Add(entity);
        }
        else
        {
            existing.Platform = platform;
            existing.DeviceId = string.IsNullOrWhiteSpace(request.DeviceId) ? null : request.DeviceId.Trim();
            existing.IsActive = true;
            existing.LastSeenAtUtc = now;
            existing.UpdatedAt = now;
        }

        await _db.SaveChangesAsync();
        return Ok(new { Message = "Registered" });
    }

    public class UnregisterDeviceTokenRequest
    {
        public string Token { get; set; } = string.Empty;
    }

    [HttpPost("device-tokens/unregister")]
    public async Task<IActionResult> Unregister([FromBody] UnregisterDeviceTokenRequest request)
    {
        var token = (request.Token ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(token)) return BadRequest("token is required");

        var userId = User.GetUserId();
        var now = DateTime.UtcNow;

        var existing = await _db.DeviceTokens
            .FirstOrDefaultAsync(d => d.UserId == userId && d.Token == token);

        if (existing == null) return Ok(new { Message = "Not found" });

        existing.IsActive = false;
        existing.UpdatedAt = now;
        await _db.SaveChangesAsync();

        return Ok(new { Message = "Unregistered" });
    }

    private static DevicePlatform ParsePlatform(string? platform)
    {
        if (string.IsNullOrWhiteSpace(platform)) return DevicePlatform.Unknown;
        var p = platform.Trim();

        if (Enum.TryParse<DevicePlatform>(p, ignoreCase: true, out var parsed))
        {
            return parsed;
        }

        return DevicePlatform.Unknown;
    }
}

