using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Strategy.Dtos;

public class UserStrategyDto
{
    public StrategyGoal PrimaryGoal { get; set; }
    public ToneVoice Tone { get; set; }
    public string ForbiddenTopics { get; set; } = string.Empty;
    public string Language { get; set; } = "tr";
    public int PostsPerDay { get; set; }
}

public class UpdateStrategyRequest
{
    public StrategyGoal PrimaryGoal { get; set; }
    public ToneVoice Tone { get; set; }
    public string ForbiddenTopics { get; set; } = string.Empty;
    public string Language { get; set; } = "tr";
}
