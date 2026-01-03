using Microsoft.EntityFrameworkCore;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.Strategy.Dtos;
using TX_Manager.Domain.Entities;

namespace TX_Manager.Infrastructure.Services;

public class StrategyService : IStrategyService
{
    private readonly IApplicationDbContext _context;

    public StrategyService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<UserStrategyDto?> GetUserStrategyAsync(Guid userId)
    {
        var strategy = await _context.UserStrategies
            .FirstOrDefaultAsync(s => s.UserId == userId);

        if (strategy == null) return null;

        return new UserStrategyDto
        {
            PrimaryGoal = strategy.PrimaryGoal,
            Tone = strategy.Tone,
            ForbiddenTopics = strategy.ForbiddenTopics,
            Language = strategy.Language,
            PostsPerDay = strategy.PostsPerDay
        };
    }

    public async Task UpdateUserStrategyAsync(Guid userId, UpdateStrategyRequest request)
    {
        var strategy = await _context.UserStrategies
            .FirstOrDefaultAsync(s => s.UserId == userId);

        if (strategy == null)
        {
            strategy = new UserStrategy
            {
                UserId = userId
            };
            _context.UserStrategies.Add(strategy);
        }

        strategy.PrimaryGoal = request.PrimaryGoal;
        strategy.Tone = request.Tone;
        strategy.ForbiddenTopics = request.ForbiddenTopics;
        strategy.Language = request.Language;
        // Keep default PostsPerDay or add to request if needed

        await _context.SaveChangesAsync(CancellationToken.None);
    }

    public async Task<bool> HasStrategyAsync(Guid userId)
    {
        return await _context.UserStrategies.AnyAsync(s => s.UserId == userId);
    }
}
