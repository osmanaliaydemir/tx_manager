using TX_Manager.Application.Strategy.Dtos;

namespace TX_Manager.Application.Common.Interfaces;

public interface IStrategyService
{
    Task<UserStrategyDto?> GetUserStrategyAsync(Guid userId);
    Task UpdateUserStrategyAsync(Guid userId, UpdateStrategyRequest request);
    Task<bool> HasStrategyAsync(Guid userId);
}
