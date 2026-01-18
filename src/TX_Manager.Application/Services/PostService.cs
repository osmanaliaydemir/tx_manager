using System;
using System.Collections.Generic;
using System.Linq;
using System.Diagnostics;
using System.Threading.Tasks;
using Mapster;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Net;
using TX_Manager.Application.Common.Exceptions;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.Common.Models;
using TX_Manager.Application.Common.Time;
using TX_Manager.Application.DTOs;
using TX_Manager.Domain.Entities;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Services;

public class PostService : IPostService
{
    private readonly IApplicationDbContext _context;
    private readonly IXApiService _xApi;
    private readonly ITokenEncryptionService _encryption;
    private readonly IPushNotificationService _push;
    private readonly ILogger<PostService> _logger;

    public PostService(
        IApplicationDbContext context, 
        IXApiService xApi,
        ITokenEncryptionService encryption,
        IPushNotificationService push,
        ILogger<PostService> logger)
    {
        _context = context;
        _xApi = xApi;
        _encryption = encryption;
        _push = push;
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
        if (dto.ScheduledFor.HasValue)
        {
            var now = DateTime.UtcNow;
            if (dto.ScheduledFor.Value.Kind == DateTimeKind.Unspecified)
            {
                // Legacy clients might send local time without Z; use stored offset if available.
                var offsetMinutes = await _context.Users
                    .Where(u => u.Id == dto.UserId)
                    .Select(u => u.TimeZoneOffsetMinutes)
                    .FirstOrDefaultAsync();

                post.ScheduledFor = SchedulingTime.NormalizeToUtc(dto.ScheduledFor.Value, now, offsetMinutes);
            }
            else
            {
                post.ScheduledFor = SchedulingTime.NormalizeToUtc(dto.ScheduledFor.Value, now);
            }
            post.Status = PostStatus.Scheduled;
        }
        else
        {
            post.Status = PostStatus.Draft;
        }

        _context.Posts.Add(post);
        await _context.SaveChangesAsync();

        return post.Adapt<PostDto>();
    }

    public async Task<IEnumerable<PostDto>> CreateThreadAsync(CreateThreadDto dto)
    {
        if (dto.Contents == null || dto.Contents.Count == 0)
            throw new ArgumentException("Thread contents cannot be empty.");

        var threadId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        DateTime? normalizedScheduledFor = null;
        if (dto.ScheduledFor.HasValue)
        {
            if (dto.ScheduledFor.Value.Kind == DateTimeKind.Unspecified)
            {
                var offsetMinutes = await _context.Users
                    .Where(u => u.Id == dto.UserId)
                    .Select(u => u.TimeZoneOffsetMinutes)
                    .FirstOrDefaultAsync();

                normalizedScheduledFor = SchedulingTime.NormalizeToUtc(dto.ScheduledFor.Value, now, offsetMinutes);
            }
            else
            {
                normalizedScheduledFor = SchedulingTime.NormalizeToUtc(dto.ScheduledFor.Value, now);
            }
        }

        var posts = dto.Contents
            .Select((content, idx) => new Post
            {
                UserId = dto.UserId,
                Content = content,
                ThreadId = threadId,
                ThreadIndex = idx,
                ScheduledFor = normalizedScheduledFor,
                Status = normalizedScheduledFor.HasValue ? PostStatus.Scheduled : PostStatus.Draft
            })
            .ToList();

        _context.Posts.AddRange(posts);
        await _context.SaveChangesAsync();

        return posts.Adapt<IEnumerable<PostDto>>();
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

    public async Task<PostDto> GetPostByIdAsync(Guid userId, Guid id)
    {
        var post = await _context.Posts.FindAsync(id);
        if (post == null || post.UserId != userId) throw new KeyNotFoundException("Post not found.");
        return post.Adapt<PostDto>();
    }

    public async Task<PostDto> UpdatePostAsync(Guid userId, Guid id, string content, DateTime? scheduledFor)
    {
        var post = await _context.Posts.FindAsync(id);
        if (post == null || post.UserId != userId) throw new KeyNotFoundException("Post not found.");
        
        if (post.Status == PostStatus.Published) throw new InvalidOperationException("Cannot update published posts.");

        post.Content = content;
        if (scheduledFor.HasValue)
        {
            var now = DateTime.UtcNow;
            if (scheduledFor.Value.Kind == DateTimeKind.Unspecified)
            {
                var offsetMinutes = await _context.Users
                    .Where(u => u.Id == post.UserId)
                    .Select(u => u.TimeZoneOffsetMinutes)
                    .FirstOrDefaultAsync();

                post.ScheduledFor = SchedulingTime.NormalizeToUtc(scheduledFor.Value, now, offsetMinutes);
            }
            else
            {
                post.ScheduledFor = SchedulingTime.NormalizeToUtc(scheduledFor.Value, now);
            }
            post.Status = PostStatus.Scheduled;
            // Retry semantics: If a post was previously failed, rescheduling should clear failure info
            post.FailureReason = null;
            post.FailureCode = null;
            post.XPostId = null;
        }
        // If content changed but no date provided, keep as is? Or if User cleared date? 
        // For simplicity, we assume editing a scheduled post keeps it scheduled unless date is removed.
        // But the input is nullable. If null, we might keep existing Schedule? Or remove schedule (draft)?
        // User requested removing/changing schedule. Let's assume nullable means "don't change date"
        // But if user wants to change date, they send new date.
        // If user wants to Draft, that's a different action.
        // For now, simple update.

        await _context.SaveChangesAsync();
        return post.Adapt<PostDto>();
    }

    public async Task DeletePostAsync(Guid userId, Guid id)
    {
        var post = await _context.Posts.FindAsync(id);
        if (post == null || post.UserId != userId) throw new KeyNotFoundException("Post not found.");

        // Unlink related ContentSuggestions to prevent FK violation
        var linkedSuggestions = await _context.ContentSuggestions
            .Where(cs => cs.ScheduledPostId == id)
            .ToListAsync();

        foreach (var suggestion in linkedSuggestions)
        {
            suggestion.ScheduledPostId = null;
            // Optionally, we could reset status to Pending or Rejected, 
            // but for now, we just remove the link to allow deletion.
        }

         _context.Posts.Remove(post);
        await _context.SaveChangesAsync();
    }

    public async Task CancelScheduleAsync(Guid userId, Guid id)
    {
        var post = await _context.Posts.FindAsync(id);
        if (post == null || post.UserId != userId) throw new KeyNotFoundException("Post not found.");
        if (post.Status == PostStatus.Published) throw new InvalidOperationException("Cannot cancel published posts.");

        post.ScheduledFor = null;
        post.Status = PostStatus.Draft;
        post.FailureReason = null;
        post.FailureCode = null;

        await _context.SaveChangesAsync();
    }

    public async Task<PublishRunResult> PublishScheduledPostsAsync()
    {
        _logger.LogInformation("Checking for scheduled posts...");

        var nowUtc = DateTime.UtcNow;
        var lockUntil = nowUtc.AddMinutes(5);
        var startedAt = nowUtc;
        var sw = Stopwatch.StartNew();
        var result = new PublishRunResult
        {
            StartedAtUtc = startedAt,
        };

        // Only publish "head" posts:
        // - non-thread posts (ThreadId == null)
        // - thread head (ThreadIndex == 0)
        // This avoids partial thread publishes and enables per-thread locking.
        var dueHeads = await _context.Posts
            .Include(p => p.User)
            .ThenInclude(u => u.AuthToken)
            .Where(p => p.Status == PostStatus.Scheduled
                        && p.ScheduledFor != null
                        && p.ScheduledFor <= nowUtc
                        && (p.ThreadId == null || p.ThreadIndex == 0))
            .ToListAsync();

        result.HeadsDue = dueHeads.Count;

        foreach (var head in dueHeads)
        {
            // Try to claim this head row atomically; if we can't, another worker is handling it.
            var lockId = Guid.NewGuid();
            var claimed = await TryClaimPublishHeadAsync(head.Id, nowUtc, lockUntil, lockId);
            if (!claimed)
            {
                result.SkippedLocked++;
                continue;
            }

            result.HeadsClaimed++;

            var ordered = await LoadPublishGroupAsync(head, nowUtc);
            if (ordered.Count == 0) continue;

            var first = ordered.First();

            if (first.User?.AuthToken == null)
            {
                foreach (var p in ordered)
                {
                    p.Status = PostStatus.Failed;
                    p.FailureCode = "TOKEN_MISSING";
                    p.FailureReason = "No auth token found";
                    p.PublishLockId = null;
                    p.PublishLockedUntilUtc = null;
                }
                continue;
            }

            var authToken = first.User.AuthToken;
            var accessToken = _encryption.Decrypt(authToken.EncryptedAccessToken);

            // Check Token Expiration (refresh if < 5 mins remaining)
            if (authToken.ExpiresAt <= DateTime.UtcNow.AddMinutes(5))
            {
                try
                {
                    var refreshToken = _encryption.Decrypt(authToken.EncryptedRefreshToken);
                    if (string.IsNullOrWhiteSpace(refreshToken))
                    {
                        foreach (var p in ordered)
                        {
                            p.Status = PostStatus.Failed;
                            p.FailureCode = "TOKEN_REFRESH_MISSING";
                            p.FailureReason = "Refresh token missing";
                            p.PublishLockId = null;
                            p.PublishLockedUntilUtc = null;
                        }
                        continue;
                    }

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

                    _logger.LogInformation("Token refreshed for user {UserId}", first.UserId);
                }
                catch (Exception refreshEx)
                {
                    _logger.LogError(refreshEx, "Failed to refresh token for user {UserId}", first.UserId);
                    foreach (var p in ordered)
                    {
                        p.Status = PostStatus.Failed;
                        p.FailureCode = "TOKEN_REFRESH_FAILED";
                        p.FailureReason = "Token expired and refresh failed";
                        p.PublishLockId = null;
                        p.PublishLockedUntilUtc = null;
                    }
                    continue;
                }
            }

            string? previousXId = null;
            for (var i = 0; i < ordered.Count; i++)
            {
                var post = ordered[i];
                result.PostsAttempted++;
                try
                {
                    using var scope = _logger.BeginScope(new Dictionary<string, object?>
                    {
                        ["PublishAttemptId"] = lockId,
                        ["UserId"] = post.UserId,
                        ["PostId"] = post.Id,
                        ["ThreadId"] = post.ThreadId,
                        ["ThreadIndex"] = post.ThreadIndex,
                    });

                    var xId = await _xApi.PostTweetAsync(accessToken, post.Content, previousXId);

                    post.Status = PostStatus.Published;
                    post.XPostId = xId;
                    post.FailureReason = null;
                    post.FailureCode = null;
                    post.PublishLockId = null;
                    post.PublishLockedUntilUtc = null;
                    previousXId = xId;
                    result.PostsPublished++;

                    _logger.LogInformation("Successfully published post {PostId} to X ({XPostId})", post.Id, xId);

                    // Best-effort push
                    try
                    {
                        var preview = post.Content.Length <= 140 ? post.Content : post.Content[..140];
                        await _push.NotifyPostPublishedAsync(post.UserId, post.Id, preview);
                    }
                    catch (Exception pex)
                    {
                        _logger.LogWarning(pex, "Push notify (published) failed for {PostId}", post.Id);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to publish post {Id}", post.Id);
                    post.Status = PostStatus.Failed;
                    (post.FailureCode, post.FailureReason) = MapFailure(ex);
                    post.PublishLockId = null;
                    post.PublishLockedUntilUtc = null;
                    result.PostsFailed++;

                    // Best-effort push
                    try
                    {
                        var preview = post.Content.Length <= 140 ? post.Content : post.Content[..140];
                        await _push.NotifyPostFailedAsync(post.UserId, post.Id, preview, post.FailureCode);
                    }
                    catch (Exception pex)
                    {
                        _logger.LogWarning(pex, "Push notify (failed) failed for {PostId}", post.Id);
                    }

                    // Abort rest of thread if any.
                    for (var j = i + 1; j < ordered.Count; j++)
                    {
                        ordered[j].Status = PostStatus.Failed;
                        ordered[j].FailureCode = "THREAD_ABORTED";
                        ordered[j].FailureReason = "Thread aborted: previous tweet failed";
                        ordered[j].PublishLockId = null;
                        ordered[j].PublishLockedUntilUtc = null;
                        result.PostsFailed++;
                    }
                    break;
                }
            }
        }
        
        if (dueHeads.Any())
        {
            await _context.SaveChangesAsync();
        }

        sw.Stop();
        result.FinishedAtUtc = startedAt.AddMilliseconds(sw.Elapsed.TotalMilliseconds);

        _logger.LogInformation(
            "Publish run finished. HeadsDue={HeadsDue}, HeadsClaimed={HeadsClaimed}, PostsAttempted={PostsAttempted}, Published={Published}, Failed={Failed}, SkippedLocked={SkippedLocked}, DurationMs={DurationMs}",
            result.HeadsDue,
            result.HeadsClaimed,
            result.PostsAttempted,
            result.PostsPublished,
            result.PostsFailed,
            result.SkippedLocked,
            sw.ElapsedMilliseconds);

        return result;
    }

    private async Task<List<Post>> LoadPublishGroupAsync(Post head, DateTime nowUtc)
    {
        if (head.ThreadId == null)
        {
            // Non-thread single post
            return new List<Post> { head };
        }

        // Load full thread for this head, ensuring it's still due+scheduled
        return await _context.Posts
            .Where(p => p.ThreadId == head.ThreadId
                        && p.Status == PostStatus.Scheduled
                        && p.ScheduledFor != null
                        && p.ScheduledFor <= nowUtc)
            .OrderBy(p => p.ThreadIndex ?? 0)
            .ThenBy(p => p.CreatedAt)
            .ToListAsync();
    }

    private async Task<bool> TryClaimPublishHeadAsync(Guid headId, DateTime nowUtc, DateTime lockUntilUtc, Guid lockId)
    {
        // SQL Server: atomically claim by setting a lock only if not currently locked.
        // IMPORTANT: This protects against multiple Hangfire servers / overlapping workers.
        var rows = await _context.Posts
            .Where(p => p.Id == headId
                        && p.Status == PostStatus.Scheduled
                        && p.ScheduledFor != null
                        && p.ScheduledFor <= nowUtc
                        && (p.PublishLockedUntilUtc == null || p.PublishLockedUntilUtc < nowUtc))
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(p => p.PublishLockId, lockId)
                .SetProperty(p => p.PublishLockedUntilUtc, lockUntilUtc));

        return rows == 1;
    }

    private static (string code, string message) MapFailure(Exception ex)
    {
        // Prefer explicit X API classification
        if (ex is XApiException x)
        {
            if (x.StatusCode == HttpStatusCode.TooManyRequests) return ("RATE_LIMIT", "Rate limit exceeded");
            if (x.StatusCode == HttpStatusCode.Unauthorized) return ("UNAUTHORIZED", "Unauthorized");
            if (x.StatusCode == HttpStatusCode.Forbidden) return ("FORBIDDEN", "Forbidden");
            return ("X_API_ERROR", "X API error");
        }

        // Fallback
        return ("UNKNOWN", ex.Message);
    }
}
