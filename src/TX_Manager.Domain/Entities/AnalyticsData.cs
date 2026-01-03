using System;

namespace TX_Manager.Domain.Entities;

public class AnalyticsData : BaseEntity
{
    public string MetricType { get; set; } = string.Empty; // e.g. "Followers", "Mentions"
    public double Value { get; set; }
    public DateTime DateFetched { get; set; } = DateTime.UtcNow;
    public string RawJson { get; set; } = "{}";
    
    public Guid UserId { get; set; }
    public User? User { get; set; }
}
