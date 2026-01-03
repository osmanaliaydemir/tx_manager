using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Domain.Entities;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Infrastructure.Services.AI;

public class AIGeneratorService : IAIGeneratorService
{
    private readonly IApplicationDbContext _context;
    private readonly ILanguageModelProvider _aiProvider;
    private readonly ILogger<AIGeneratorService> _logger;

    public AIGeneratorService(
        IApplicationDbContext context,
        ILanguageModelProvider aiProvider,
        ILogger<AIGeneratorService> logger)
    {
        _context = context;
        _aiProvider = aiProvider;
        _logger = logger;
    }

    public async Task GenerateSuggestionsForUserAsync(Guid userId)
    {
        var strategy = await _context.UserStrategies
            .FirstOrDefaultAsync(s => s.UserId == userId);

        if (strategy == null)
        {
            _logger.LogWarning("Cannot generate suggestions. User {UserId} has no strategy.", userId);
            return;
        }

        // 1. Construct the System Prompt
        var systemPrompt = BuildSystemPrompt(strategy);

        // 2. User Prompt (Trigger)
        var userPrompt = "Generate 3 unique content suggestions for today based on my strategy. Return ONLY JSON.";

        try
        {
            // 3. Call AI
            var responseText = await _aiProvider.GenerateTextAsync(userPrompt, systemPrompt);
            _logger.LogInformation("AI Response: {Response}", responseText);

            // 4. Parse JSON Response
            var suggestions = ParseAIResponse(responseText);

            // 5. Save to Database
            foreach (var item in suggestions)
            {
                var suggestion = new ContentSuggestion
                {
                    UserId = userId,
                    SuggestedText = item.Text,
                    Rationale = item.Rationale,
                    RiskAssessment = "Low", // Default, could be parsed too
                    EstimatedImpact = "Medium", 
                    GeneratedAt = DateTime.UtcNow,
                    Status = SuggestionStatus.Pending
                };
                _context.ContentSuggestions.Add(suggestion);
            }

            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate suggestions for User {UserId}", userId);
        }
    }

    private string BuildSystemPrompt(UserStrategy strategy)
    {
        var goalDesc = strategy.PrimaryGoal.ToString(); // e.g., Authority
        var toneDesc = strategy.Tone.ToString(); // e.g., Witty

        return $@"
You are an expert Social Media Content Strategist.
Your client is a Twitter/X user with the following profile:
- Primary Goal: {goalDesc}
- Tone of Voice: {toneDesc}
- Language: {strategy.Language}
{(string.IsNullOrEmpty(strategy.ForbiddenTopics) ? "" : $"- Forbidden Topics: {strategy.ForbiddenTopics}")}

Your task:
Generate 3 high-quality tweet suggestions. The tweets must be strictly in the user's selected language ({strategy.Language}).

Output Format:
You must return a strictly valid JSON array. Do not include markdown formatting (like ```json).
Structure:
[
  {{
    ""text"": ""The tweet content here..."",
    ""rationale"": ""Why this tweet works for the strategy...""
  }},
  ...
]
";
    }

    private List<SuggestionDto> ParseAIResponse(string json)
    {
        // Clean markdown code blocks if AI adds them
        json = json.Replace("```json", "").Replace("```", "").Trim();
        
        try 
        {
            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            return JsonSerializer.Deserialize<List<SuggestionDto>>(json, options) ?? new List<SuggestionDto>();
        }
        catch(Exception ex)
        {
            _logger.LogError("JSON Parse Error. Raw: {Json}", json);
            return new List<SuggestionDto>();
        }
    }

    private class SuggestionDto
    {
        public string Text { get; set; } = "";
        public string Rationale { get; set; } = "";
    }
}
