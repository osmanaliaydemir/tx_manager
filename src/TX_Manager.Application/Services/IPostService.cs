using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using TX_Manager.Application.DTOs;
using TX_Manager.Application.Common.Models;

using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Services;

public interface IPostService
{
    Task<PostDto> CreatePostAsync(CreatePostDto dto);
    Task<IEnumerable<PostDto>> CreateThreadAsync(CreateThreadDto dto);
    Task<IEnumerable<PostDto>> GetPostsAsync(Guid userId, PostStatus? status = null);
    Task<PostDto> GetPostByIdAsync(Guid userId, Guid id);
    Task<PostDto> UpdatePostAsync(Guid userId, Guid id, string content, DateTime? scheduledFor);
    Task CancelScheduleAsync(Guid userId, Guid id);
    Task DeletePostAsync(Guid userId, Guid id);
    Task<PublishRunResult> PublishScheduledPostsAsync(); // Logic for worker
}
