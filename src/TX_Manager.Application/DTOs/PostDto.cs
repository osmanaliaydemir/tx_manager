using System;

namespace TX_Manager.Application.DTOs;

public class CreatePostDto
{
    public string Content { get; set; } = string.Empty;
    public DateTime? ScheduledFor { get; set; }
    public Guid UserId { get; set; } // Simplified: In real app, extract from Claims
}

public class PostDto
{
    public Guid Id { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime? ScheduledFor { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? XPostId { get; set; }
    public DateTime CreatedAt { get; set; }
}
