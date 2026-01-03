using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using TX_Manager.Application.DTOs;

using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Services;

public interface IPostService
{
    Task<PostDto> CreatePostAsync(CreatePostDto dto);
    Task<IEnumerable<PostDto>> GetPostsAsync(Guid userId, PostStatus? status = null);
    Task PublishScheduledPostsAsync(); // Logic for worker
}
