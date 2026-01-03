using Microsoft.AspNetCore.Mvc;
using TX_Manager.Application.Common.Interfaces;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SuggestionController : ControllerBase
{
    private readonly IAIGeneratorService _aiService;
    private readonly IApplicationDbContext _context;

    public SuggestionController(IAIGeneratorService aiService, IApplicationDbContext context)
    {
        _aiService = aiService;
        _context = context;
    }

    [HttpPost("generate/{userId}")]
    public async Task<IActionResult> GenerateSuggestions(Guid userId)
    {
        // In real app, verify user permission
        await _aiService.GenerateSuggestionsForUserAsync(userId);
        return Ok(new { Message = "Suggestions generation triggered." });
    }

    [HttpGet("{userId}")]
    public IActionResult GetSuggestions(Guid userId)
    {
        var suggestions = _context.ContentSuggestions
            .Where(s => s.UserId == userId && s.Status == Domain.Enums.SuggestionStatus.Pending)
            .OrderByDescending(s => s.GeneratedAt)
            .Take(10)
            .Select(s => new 
            {
                s.Id,
                s.SuggestedText,
                s.Rationale,
                s.RiskAssessment,
                GeneratedAt = s.GeneratedAt.ToString("g")
            })
            .ToList();
            
        return Ok(suggestions);
    }

    [HttpPost("{id}/accept")]
    public async Task<IActionResult> AcceptSuggestion(Guid id)
    {
        var suggestion = await _context.ContentSuggestions.FindAsync(id);
        if (suggestion == null) return NotFound();

        if (suggestion.Status != Domain.Enums.SuggestionStatus.Pending)
            return BadRequest("Suggestion is not pending.");

        suggestion.Status = Domain.Enums.SuggestionStatus.Accepted;

        // Create Scheduled Post
        // Production Logic: Schedule for tomorrow at random hour between 9-18
        var randomHour = new Random().Next(9, 18);
        var scheduledTime = DateTime.UtcNow.Date.AddDays(1).AddHours(randomHour);

        var post = new Domain.Entities.Post
        {
            UserId = suggestion.UserId,
            Content = suggestion.SuggestedText, // Content from Sugg
            ScheduledFor = scheduledTime,
            Status = Domain.Enums.PostStatus.Scheduled,
            CreatedAt = DateTime.UtcNow
        };

        _context.Posts.Add(post);
        suggestion.ScheduledPost = post;

        await _context.SaveChangesAsync();
        return Ok(new { Message = "Suggestion accepted and scheduled.", ScheduledFor = scheduledTime });
    }

    [HttpPost("{id}/reject")]
    public async Task<IActionResult> RejectSuggestion(Guid id)
    {
        var suggestion = await _context.ContentSuggestions.FindAsync(id);
        if (suggestion == null) return NotFound();

        suggestion.Status = Domain.Enums.SuggestionStatus.Rejected;

        await _context.SaveChangesAsync();
        return Ok(new { Message = "Suggestion rejected." });
    }
}
