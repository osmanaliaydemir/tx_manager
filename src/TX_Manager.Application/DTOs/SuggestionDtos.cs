using System;
using System.Collections.Generic;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.DTOs;

public class SuggestionItemDto
{
    public Guid Id { get; set; }
    public string SuggestedText { get; set; } = string.Empty;
    public string Rationale { get; set; } = string.Empty;
    public string RiskAssessment { get; set; } = string.Empty;
    public string EstimatedImpact { get; set; } = string.Empty;
    public SuggestionStatus Status { get; set; }
    public DateTime GeneratedAtUtc { get; set; }
}

public class SuggestionListResponseDto
{
    public List<SuggestionItemDto> Items { get; set; } = new();
    public string? NextCursor { get; set; }
}

public enum AcceptMode
{
    Manual,
    Auto
}

public class AcceptSuggestionRequestDto
{
    public AcceptMode Mode { get; set; } = AcceptMode.Auto;
    public DateTime? ScheduledForUtc { get; set; }

    public SchedulePolicyDto? SchedulePolicy { get; set; }
}

public class SchedulePolicyDto
{
    public bool ExcludeWeekends { get; set; }

    // Local hours in user's timezone. If not provided, we only apply quiet-hours + gaps.
    public int? PreferredStartLocalHour { get; set; }
    public int? PreferredEndLocalHour { get; set; }
}

public class AcceptSuggestionResponseDto
{
    public Guid PostId { get; set; }
    public DateTime ScheduledForUtc { get; set; }
}

public class RejectSuggestionRequestDto
{
    public string? Reason { get; set; }
}

