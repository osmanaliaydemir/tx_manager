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
    private readonly IPushNotificationService _push;
    private readonly ILogger<AIGeneratorService> _logger;

    public AIGeneratorService(
        IApplicationDbContext context,
        ILanguageModelProvider aiProvider,
        IPushNotificationService push,
        ILogger<AIGeneratorService> logger)
    {
        _context = context;
        _aiProvider = aiProvider;
        _push = push;
        _logger = logger;
    }

    public async Task GenerateSuggestionsForUserAsync(Guid userId)
    {
        var strategy = await _context.UserStrategies
            .FirstOrDefaultAsync(s => s.UserId == userId);

        if (strategy == null)
        {
            _logger.LogWarning("Cannot generate suggestions. User {UserId} has no strategy.", userId);
            throw new Exception("User has no strategy defined. Please complete onboarding.");
        }

        // 1. Fetch Top Performing Posts (Feedback Loop)
        var topPosts = await _context.Posts
            .Where(p => p.UserId == userId && p.Status == PostStatus.Published)
            .OrderByDescending(p => p.LikeCount)
            .Take(5)
            .Select(p => p.Content)
            .ToListAsync();

        // 2. Construct the System Prompt
        var systemPrompt = BuildSystemPrompt(strategy, topPosts);

        // 3. User Prompt (Trigger)
        var userPrompt = "Generate 3 unique content suggestions for today based on my strategy. Return ONLY JSON.";

        try
        {
            // 4. Call AI
            var responseText = await _aiProvider.GenerateTextAsync(userPrompt, systemPrompt);
            _logger.LogInformation("AI Response: {Response}", responseText);

            // 5. Parse JSON Response
            var suggestions = ParseAIResponse(responseText);

            // 6. Save to Database
            var existingTexts = await _context.ContentSuggestions
                .Where(s => s.UserId == userId)
                .Select(s => s.SuggestedText)
                .ToListAsync();
            
            var existingSet = new HashSet<string>(existingTexts, StringComparer.OrdinalIgnoreCase);

            var inserted = 0;
            foreach (var item in suggestions)
            {
                if (existingSet.Contains(item.Text))
                {
                    continue; 
                }
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
                inserted++;
            }

            await _context.SaveChangesAsync();

            // Best-effort push
            if (inserted > 0)
            {
                try
                {
                    await _push.NotifySuggestionsReadyAsync(userId, inserted);
                }
                catch (Exception pex)
                {
                    _logger.LogWarning(pex, "Push notify (suggestions_ready) failed for user {UserId}", userId);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate suggestions for User {UserId}", userId);
            throw; // Re-throw to let the controller know
        }
    }

    private string BuildSystemPrompt(UserStrategy strategy, List<string> topPosts)
    {
        var goalDesc = strategy.PrimaryGoal.ToString(); // e.g., Authority
        var toneDesc = strategy.Tone.ToString(); // e.g., Witty
        
        var historyContext = "";
        if (topPosts.Any())
        {
            historyContext = "Here are some of the user's best performing past tweets. Use them as inspiration for style, format and topics, but do not copy them directly:\n";
            foreach(var post in topPosts)
            {
                 historyContext += $"- \"{post}\"\n";
            }
        }

        return $@"
You are an expert Social Media Content Strategist.
Your client is a Twitter/X user with the following profile:
- Primary Goal: {goalDesc}
- Tone of Voice: {toneDesc}
- Language: {strategy.Language}
{(string.IsNullOrEmpty(strategy.ForbiddenTopics) ? "" : $"- Forbidden Topics: {strategy.ForbiddenTopics}")}

{historyContext}

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
            throw new Exception($"Failed to parse AI response. Raw: {json}");
        }
    }

    private class SuggestionDto
    {
        public string Text { get; set; } = "";
        public string Rationale { get; set; } = "";
    }
}
