using Hangfire;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TX_Manager.Api.Auth;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.DTOs;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/suggestions")]
[Authorize]
public class SuggestionController : ControllerBase
{
    private readonly IAIGeneratorService _aiService;
    private readonly ISuggestionService _suggestions;
    private readonly IBackgroundJobClient _jobs;

    public SuggestionController(
        IAIGeneratorService aiService,
        ISuggestionService suggestions,
        IBackgroundJobClient jobs)
    {
        _aiService = aiService;
        _suggestions = suggestions;
        _jobs = jobs;
    }

    [HttpPost("generate")]
    public IActionResult GenerateSuggestions()
    {
        var userId = User.GetUserId();
        var jobId = _jobs.Enqueue(() => _aiService.GenerateSuggestionsForUserAsync(userId));
        return Accepted(new { JobId = jobId });
    }

    [HttpGet]
    public async Task<IActionResult> GetSuggestions(
        [FromQuery] string? status,
        [FromQuery] string? cursor,
        [FromQuery] int take = 20)
    {
        var userId = User.GetUserId();

        SuggestionStatus? parsedStatus = null;
        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!Enum.TryParse<SuggestionStatus>(status, ignoreCase: true, out var st))
            {
                return BadRequest("Invalid status. Use Pending/Accepted/Rejected/Edited.");
            }
            parsedStatus = st;
        }

        var result = await _suggestions.GetSuggestionsAsync(userId, parsedStatus, cursor, take);
        return Ok(result);
    }

    [HttpPost("{id}/accept")]
    public async Task<IActionResult> AcceptSuggestion(
        Guid id,
        [FromBody] AcceptSuggestionRequestDto request)
    {
        var userId = User.GetUserId();

        try
        {
            var res = await _suggestions.AcceptAsync(userId, id, request);
            return Ok(res);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException e)
        {
            return BadRequest(e.Message);
        }
    }

    [HttpPost("{id}/reject")]
    public async Task<IActionResult> RejectSuggestion(
        Guid id,
        [FromBody] RejectSuggestionRequestDto? request)
    {
        var userId = User.GetUserId();

        try
        {
            await _suggestions.RejectAsync(userId, id, request?.Reason);
            return Ok();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException e)
        {
            return BadRequest(e.Message);
        }
    }
}
