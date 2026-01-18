using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TX_Manager.Api.Auth;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.DTOs;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/analytics")]
[Authorize]
public class AnalyticsController : ControllerBase
{
    private readonly IApplicationDbContext _context;

    public AnalyticsController(IApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary([FromQuery] int days = 30)
    {
        if (days <= 0) return BadRequest("days must be > 0");
        days = Math.Min(days, 365);

        var userId = User.GetUserId();
        var fromUtc = DateTime.UtcNow.AddDays(-days);

        var baseQuery = _context.Posts
            .AsNoTracking()
            .Where(p => p.UserId == userId);

        var totalPosts = await baseQuery.CountAsync();

        var byStatus = await baseQuery
            .GroupBy(p => p.Status)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToListAsync();

        int Count(PostStatus st) => byStatus.FirstOrDefault(x => x.Status == st)?.Count ?? 0;

        var publishedRecent = baseQuery
            .Where(p => p.Status == PostStatus.Published && p.CreatedAt >= fromUtc);

        var publishedCount = await publishedRecent.CountAsync();

        var totals = await publishedRecent
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Impressions = (long)g.Sum(p => p.ImpressionCount),
                Likes = (long)g.Sum(p => p.LikeCount),
                Retweets = (long)g.Sum(p => p.RetweetCount),
                Replies = (long)g.Sum(p => p.ReplyCount),
                LastUpdate = g.Max(p => p.LastMetricsUpdate)
            })
            .FirstOrDefaultAsync();

        long totalImpressions = totals?.Impressions ?? 0;
        long totalLikes = totals?.Likes ?? 0;
        long totalRetweets = totals?.Retweets ?? 0;
        long totalReplies = totals?.Replies ?? 0;
        var lastUpdateUtc = totals?.LastUpdate;

        double Avg(long v) => publishedCount <= 0 ? 0 : (double)v / publishedCount;

        var dto = new AnalyticsSummaryDto
        {
            Days = days,
            TotalPosts = totalPosts,
            DraftCount = Count(PostStatus.Draft),
            ScheduledCount = Count(PostStatus.Scheduled),
            PublishedCount = Count(PostStatus.Published),
            FailedCount = Count(PostStatus.Failed),
            TotalImpressions = totalImpressions,
            TotalLikes = totalLikes,
            TotalRetweets = totalRetweets,
            TotalReplies = totalReplies,
            AvgImpressionsPerPublished = Avg(totalImpressions),
            AvgLikesPerPublished = Avg(totalLikes),
            AvgRetweetsPerPublished = Avg(totalRetweets),
            AvgRepliesPerPublished = Avg(totalReplies),
            LastMetricsUpdateUtc = lastUpdateUtc
        };

        return Ok(dto);
    }

    [HttpGet("timeseries")]
    public async Task<IActionResult> GetTimeseries([FromQuery] int days = 30)
    {
        if (days <= 0) return BadRequest("days must be > 0");
        days = Math.Min(days, 365);

        var userId = User.GetUserId();
        var fromUtc = DateTime.UtcNow.Date.AddDays(-days + 1); // include today as a bucket

        var points = await _context.Posts
            .AsNoTracking()
            .Where(p => p.UserId == userId
                        && p.Status == PostStatus.Published
                        && p.CreatedAt >= fromUtc)
            .GroupBy(p => p.CreatedAt.Date)
            .Select(g => new AnalyticsTimeseriesPointDto
            {
                DateUtc = g.Key,
                PublishedCount = g.Count(),
                Impressions = (long)g.Sum(p => p.ImpressionCount),
                Likes = (long)g.Sum(p => p.LikeCount),
                Retweets = (long)g.Sum(p => p.RetweetCount),
                Replies = (long)g.Sum(p => p.ReplyCount),
            })
            .OrderBy(p => p.DateUtc)
            .ToListAsync();

        return Ok(new AnalyticsTimeseriesDto { Days = days, Points = points });
    }

    [HttpGet("top")]
    public async Task<IActionResult> GetTop(
        [FromQuery] int days = 30,
        [FromQuery] int take = 10,
        [FromQuery] string sortBy = "impressions")
    {
        if (days <= 0) return BadRequest("days must be > 0");
        days = Math.Min(days, 365);
        take = Math.Clamp(take, 1, 50);

        sortBy = (sortBy ?? "impressions").Trim().ToLowerInvariant();
        if (sortBy is not ("impressions" or "likes" or "retweets" or "replies"))
        {
            return BadRequest("sortBy must be one of: impressions, likes, retweets, replies");
        }

        var userId = User.GetUserId();
        var fromUtc = DateTime.UtcNow.AddDays(-days);

        var q = _context.Posts
            .AsNoTracking()
            .Where(p => p.UserId == userId
                        && p.Status == PostStatus.Published
                        && p.CreatedAt >= fromUtc);

        q = sortBy switch
        {
            "likes" => q.OrderByDescending(p => p.LikeCount),
            "retweets" => q.OrderByDescending(p => p.RetweetCount),
            "replies" => q.OrderByDescending(p => p.ReplyCount),
            _ => q.OrderByDescending(p => p.ImpressionCount),
        };

        var items = await q
            .Take(take)
            .Select(p => new AnalyticsTopPostDto
            {
                Id = p.Id,
                ContentPreview = p.Content.Length <= 180 ? p.Content : p.Content.Substring(0, 180),
                CreatedAtUtc = p.CreatedAt,
                XPostId = p.XPostId,
                ImpressionCount = p.ImpressionCount,
                LikeCount = p.LikeCount,
                RetweetCount = p.RetweetCount,
                ReplyCount = p.ReplyCount
            })
            .ToListAsync();

        return Ok(new AnalyticsTopPostsDto
        {
            Days = days,
            SortBy = sortBy,
            Take = take,
            Items = items
        });
    }
}

