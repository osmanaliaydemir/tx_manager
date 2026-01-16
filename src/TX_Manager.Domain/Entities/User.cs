using System;
using System.Collections.Generic;

namespace TX_Manager.Domain.Entities;

public class User : BaseEntity
{
    public string Username { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string ProfileImageUrl { get; set; } = string.Empty;
    public string XUserId { get; set; } = string.Empty;

    // Client timezone info (best-effort; used for UX and future calendar features)
    public string? TimeZoneName { get; set; } // e.g. "TRT", "GMT+3", "Europe/Istanbul" (if available)
    public int? TimeZoneOffsetMinutes { get; set; } // e.g. 180 for UTC+3
    
    // Navigation props
    public ICollection<Post> Posts { get; set; } = new List<Post>();
    public AuthToken? AuthToken { get; set; }
    public ICollection<AnalyticsData> AnalyticsData { get; set; } = new List<AnalyticsData>();
}
