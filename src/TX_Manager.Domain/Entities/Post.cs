using System;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Domain.Entities;

public class Post : BaseEntity
{
    public string Content { get; set; } = string.Empty;
    public DateTime? ScheduledFor { get; set; }
    public PostStatus Status { get; set; } = PostStatus.Draft;
    
    // Thread support (X reply chain)
    public Guid? ThreadId { get; set; }
    public int? ThreadIndex { get; set; } // 0-based order inside thread

    // Idempotency / publishing lock (prevents double publish across workers)
    public Guid? PublishLockId { get; set; }
    public DateTime? PublishLockedUntilUtc { get; set; }

    // Id returned from X after publishing
    public string? XPostId { get; set; }
    
    // Error message if failed
    public string? FailureReason { get; set; }

    // Standardized failure code (TOKEN_MISSING, RATE_LIMIT, X_API_ERROR, etc.)
    public string? FailureCode { get; set; }

    public Guid UserId { get; set; }
    public User? User { get; set; }

    // Analytics
    public int LikeCount { get; set; }
    public int RetweetCount { get; set; }
    public int ReplyCount { get; set; }
    public int ImpressionCount { get; set; }
    public DateTime? LastMetricsUpdate { get; set; }
}
