using System;
using System.Threading.Tasks;
using TX_Manager.Application.DTOs;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Common.Interfaces;

public interface ISuggestionService
{
    Task<SuggestionListResponseDto> GetSuggestionsAsync(
        Guid userId,
        SuggestionStatus? status,
        string? cursor,
        int take);

    Task<AcceptSuggestionResponseDto> AcceptAsync(Guid userId, Guid suggestionId, AcceptSuggestionRequestDto request);

    Task RejectAsync(Guid userId, Guid suggestionId, string? reason);
}

