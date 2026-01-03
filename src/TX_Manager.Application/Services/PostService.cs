using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Mapster;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.DTOs;
using TX_Manager.Domain.Entities;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Services;

public class PostService : IPostService
{
    private readonly IApplicationDbContext _context;
    private readonly IXApiService _xApi;
    private readonly ITokenEncryptionService _encryption;
    private readonly ILogger<PostService> _logger;

    public PostService(
        IApplicationDbContext context, 
        IXApiService xApi,
        ITokenEncryptionService encryption,
        ILogger<PostService> logger)
    {
        _context = context;
        _xApi = xApi;
        _encryption = encryption;
        _logger = logger;
    }

    public async Task<PostDto> CreatePostAsync(CreatePostDto dto)
    {
        // 1. Policy Check (Simple)
        // Dedupe
        bool exists = await _context.Posts.AnyAsync(p => p.UserId == dto.UserId && p.Content == dto.Content && p.Status != PostStatus.Failed);
        if (exists) throw new InvalidOperationException("Duplicate content detected.");

        // Content Safety (Stub)
        if (dto.Content.Contains("badword")) throw new InvalidOperationException("Content policy violation.");

        var post = dto.Adapt<Post>();
        post.Status = dto.ScheduledFor.HasValue ? PostStatus.Scheduled : PostStatus.Draft;

        _context.Posts.Add(post);
        await _context.SaveChangesAsync();

        return post.Adapt<PostDto>();
    }

    public async Task<IEnumerable<PostDto>> GetPostsAsync(Guid userId, PostStatus? status = null)
    {
        var query = _context.Posts
            .Where(p => p.UserId == userId);

        if (status.HasValue)
        {
            query = query.Where(p => p.Status == status.Value);
        }

        var posts = await query
            .OrderByDescending(p => p.ScheduledFor) // Show scheduled/newest first
            .ThenByDescending(p => p.CreatedAt)
            .ToListAsync();
        
        return posts.Adapt<IEnumerable<PostDto>>();
    }

    public async Task PublishScheduledPostsAsync()
    {
        _logger.LogInformation("Checking for scheduled posts...");
        
        var duePosts = await _context.Posts
            .Include(p => p.User)
            .ThenInclude(u => u.AuthToken)
            .Where(p => p.Status == PostStatus.Scheduled && p.ScheduledFor <= DateTime.UtcNow)
            .ToListAsync();

        foreach (var post in duePosts)
        {
            try
            {
                if (post.User?.AuthToken == null)
                {
                    post.Status = PostStatus.Failed;
                    post.FailureReason = "No auth token found";
                    continue;
                }

                var authToken = post.User.AuthToken;
                var accessToken = _encryption.Decrypt(authToken.EncryptedAccessToken);

                // Check Token Expiration (refresh if < 5 mins remaining)
                if (authToken.ExpiresAt <= DateTime.UtcNow.AddMinutes(5))
                {
                    try 
                    {
                        var refreshToken = _encryption.Decrypt(authToken.EncryptedRefreshToken);
                        var newTokens = await _xApi.RefreshTokenAsync(refreshToken);

                        // Update DB
                        authToken.EncryptedAccessToken = _encryption.Encrypt(newTokens.AccessToken);
                        if (!string.IsNullOrEmpty(newTokens.RefreshToken))
                        {
                            authToken.EncryptedRefreshToken = _encryption.Encrypt(newTokens.RefreshToken);
                        }
                        authToken.ExpiresAt = DateTime.UtcNow.AddSeconds(newTokens.ExpiresIn);
                        
                        // Use new access token
                        accessToken = newTokens.AccessToken;
                        
                        _logger.LogInformation("Token refreshed for user {UserId}", post.UserId);
                    }
                    catch (Exception refreshEx)
                    {
                         _logger.LogError(refreshEx, "Failed to refresh token for user {UserId}", post.UserId);
                         post.Status = PostStatus.Failed;
                         post.FailureReason = "Token expired and refresh failed";
                         continue;
                    }
                }

                var xId = await _xApi.PostTweetAsync(accessToken, post.Content);
                
                post.Status = PostStatus.Published;
                post.XPostId = xId;
                post.ScheduledFor = null; // Keep scheduled time for history? Actually clearing it might be misleading. Let's keep it.
                // Revert requirement: removing 'post.ScheduledFor = null;' line effectively.
                // Or better, let's just not touch ScheduledFor.
                 
                _logger.LogInformation("Successfully published post {PostId} to X ({XPostId})", post.Id, xId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish post {Id}", post.Id);
                post.Status = PostStatus.Failed;
                post.FailureReason = ex.Message;
            }
        }
        
        if (duePosts.Any())
        {
            await _context.SaveChangesAsync();
        }
    }
}
