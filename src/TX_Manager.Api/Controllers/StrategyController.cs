using Microsoft.AspNetCore.Mvc;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.Strategy.Dtos;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StrategyController : ControllerBase
{
    private readonly IStrategyService _strategyService;
    private readonly IApplicationDbContext _context; // For direct user check if needed, but service should handle logic

    public StrategyController(IStrategyService strategyService)
    {
        _strategyService = strategyService;
    }

    [HttpGet("{userId}")] // In production, get userId from Auth Token Claims
    public async Task<IActionResult> GetStrategy(Guid userId)
    {
        var strategy = await _strategyService.GetUserStrategyAsync(userId);
        if (strategy == null) return NotFound("Strategy not defined yet.");
        return Ok(strategy);
    }

    [HttpPost("{userId}")] // In production, get userId from Auth Token Claims
    public async Task<IActionResult> UpdateStrategy(Guid userId, [FromBody] UpdateStrategyRequest request)
    {
        await _strategyService.UpdateUserStrategyAsync(userId, request);
        return Ok(new { Message = "Strategy updated successfully" });
    }
}
