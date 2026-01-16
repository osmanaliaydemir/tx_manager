using System;
using System.Collections.Generic;

namespace TX_Manager.Application.DTOs;

public class CreatePostDto
{
    public string Content { get; set; } = string.Empty;
    public DateTime? ScheduledFor { get; set; }
    public Guid UserId { get; set; } // Simplified: In real app, extract from Claims

    // Thread support (optional)
    public Guid? ThreadId { get; set; }
    public int? ThreadIndex { get; set; }
}

public class CreateThreadDto
{
    public Guid UserId { get; set; }
    public DateTime? ScheduledFor { get; set; }
    public List<string> Contents { get; set; } = new();
}

public class PostDto
{
    public Guid Id { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime? ScheduledFor { get; set; }
    // PostStatus enum value (Draft=0, Scheduled=1, Published=2, Failed=3)
    public int Status { get; set; }
    public string? XPostId { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? FailureReason { get; set; }
    public string? FailureCode { get; set; }

    // Thread support
    public Guid? ThreadId { get; set; }
    public int? ThreadIndex { get; set; }
    
    // Analytics
    public int LikeCount { get; set; }
    public int RetweetCount { get; set; }
    public int ReplyCount { get; set; }
    public int ImpressionCount { get; set; }
}
