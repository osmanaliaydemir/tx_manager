using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Services;

public class AnalyticsService : IAnalyticsService
{
    private readonly IApplicationDbContext _context;
    private readonly IXApiService _xApi;
    private readonly ITokenEncryptionService _encryption;
    private readonly ILogger<AnalyticsService> _logger;

    public AnalyticsService(
        IApplicationDbContext context,
        IXApiService xApi,
        ITokenEncryptionService encryption,
        ILogger<AnalyticsService> logger)
    {
        _context = context;
        _xApi = xApi;
        _encryption = encryption;
        _logger = logger;
    }

    public async Task UpdateMetricsForRecentPostsAsync()
    {
        var sevenDaysAgo = DateTime.UtcNow.AddDays(-7);
        
        var recentPosts = await _context.Posts
            .Include(p => p.User)
            .ThenInclude(u => u.AuthToken)
            .Where(p => p.Status == PostStatus.Published && 
                        p.XPostId != null && 
                        p.CreatedAt >= sevenDaysAgo)
            .ToListAsync();

        if (!recentPosts.Any()) return;

        // Group by User to use their specific token
        var groupedPosts = recentPosts.GroupBy(p => p.UserId);

        foreach (var group in groupedPosts)
        {
            var user = group.First().User;
            if (user?.AuthToken == null) continue;

            var authToken = user.AuthToken;
            string accessToken;

            try 
            {
                // Decrypt
                accessToken = _encryption.Decrypt(authToken.EncryptedAccessToken);

                // Token Refresh Logic (Duplicate from PostService, maybe refactor later)
                if (authToken.ExpiresAt <= DateTime.UtcNow.AddMinutes(5))
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
                     accessToken = newTokens.AccessToken;
                     
                     _logger.LogInformation("Token refreshed for Analytics for user {UserId}", user.Id);
                }
                
                var tweetIds = group.Select(p => p.XPostId!).ToList();
                var metrics = await _xApi.GetTweetMetricsAsync(accessToken, tweetIds);

                foreach (var post in group)
                {
                    if (metrics.TryGetValue(post.XPostId!, out var m))
                    {
                        post.LikeCount = m.LikeCount;
                        post.RetweetCount = m.RetweetCount;
                        post.ReplyCount = m.ReplyCount;
                        post.ImpressionCount = m.ImpressionCount;
                        post.LastMetricsUpdate = DateTime.UtcNow;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating metrics for user {UserId}", user.Id);
            }
        }

        await _context.SaveChangesAsync();
    }
}
