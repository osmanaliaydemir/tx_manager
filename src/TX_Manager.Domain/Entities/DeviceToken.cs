using System;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Domain.Entities;

public class DeviceToken : BaseEntity
{
    public Guid UserId { get; set; }
    public User? User { get; set; }

    // FCM/APNs token (or any push provider token)
    public string Token { get; set; } = string.Empty;

    public DevicePlatform Platform { get; set; } = DevicePlatform.Unknown;

    // Optional: help dedupe per device
    public string? DeviceId { get; set; }

    public bool IsActive { get; set; } = true;
    public DateTime LastSeenAtUtc { get; set; } = DateTime.UtcNow;
}

