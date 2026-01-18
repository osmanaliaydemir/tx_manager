using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TX_Manager.Api.Auth;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.Strategy.Dtos;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/strategy")]
[Authorize]
public class StrategyController : ControllerBase
{
    private readonly IStrategyService _strategyService;

    public StrategyController(IStrategyService strategyService)
    {
        _strategyService = strategyService;
    }

    [HttpGet]
    public async Task<IActionResult> GetStrategy()
    {
        var userId = User.GetUserId();
        var strategy = await _strategyService.GetUserStrategyAsync(userId);
        if (strategy == null) return NotFound("Strategy not defined yet.");
        return Ok(strategy);
    }

    [HttpPost]
    public async Task<IActionResult> UpdateStrategy([FromBody] UpdateStrategyRequest request)
    {
        var userId = User.GetUserId();
        await _strategyService.UpdateUserStrategyAsync(userId, request);
        return Ok(new { Message = "Strategy updated successfully" });
    }
}
