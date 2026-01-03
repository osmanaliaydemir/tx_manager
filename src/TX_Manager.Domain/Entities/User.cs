using System;
using System.Collections.Generic;

namespace TX_Manager.Domain.Entities;

public class User : BaseEntity
{
    public string Username { get; set; } = string.Empty;
    public string XUserId { get; set; } = string.Empty;
    
    // Navigation props
    public ICollection<Post> Posts { get; set; } = new List<Post>();
    public AuthToken? AuthToken { get; set; }
    public ICollection<AnalyticsData> AnalyticsData { get; set; } = new List<AnalyticsData>();
}
