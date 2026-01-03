using System;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Domain.Entities;

public class Post : BaseEntity
{
    public string Content { get; set; } = string.Empty;
    public DateTime? ScheduledFor { get; set; }
    public PostStatus Status { get; set; } = PostStatus.Draft;
    
    // Id returned from X after publishing
    public string? XPostId { get; set; }
    
    // Error message if failed
    public string? FailureReason { get; set; }

    public Guid UserId { get; set; }
    public User? User { get; set; }

    // Analytics
    public int LikeCount { get; set; }
    public int RetweetCount { get; set; }
    public int ReplyCount { get; set; }
    public int ImpressionCount { get; set; }
    public DateTime? LastMetricsUpdate { get; set; }
}
