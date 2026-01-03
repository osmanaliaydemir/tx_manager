using System;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Domain.Entities;

public class ContentSuggestion : BaseEntity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    public string SuggestedText { get; set; } = string.Empty; 
    public string Rationale { get; set; } = string.Empty; 
    
    public string RiskAssessment { get; set; } = "Low"; // Low, Medium, High
    public string EstimatedImpact { get; set; } = "Unknown"; // e.g. "High Engagement potential"

    public SuggestionStatus Status { get; set; } = SuggestionStatus.Pending;
    public string? RejectionReason { get; set; } 

    public DateTime GeneratedAt { get; set; } = DateTime.UtcNow;

    public Guid? ScheduledPostId { get; set; }
    public Post? ScheduledPost { get; set; }
}
