using System;
using System.Collections.Generic;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Domain.Entities;

public class UserStrategy : BaseEntity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    public StrategyGoal PrimaryGoal { get; set; }
    public ToneVoice Tone { get; set; }
    
    // JSON or CSV content for forbidden topics
    public string ForbiddenTopics { get; set; } = string.Empty; 
    
    // Preferred Language (tr, en)
    public string Language { get; set; } = "tr";
    
    // Frequency preference (e.g., posts per day)
    public int PostsPerDay { get; set; } = 3;
}
