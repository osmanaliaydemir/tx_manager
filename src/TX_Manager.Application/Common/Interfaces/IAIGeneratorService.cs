using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Common.Interfaces;

public interface IAIGeneratorService
{
    Task GenerateSuggestionsForUserAsync(Guid userId);
}
