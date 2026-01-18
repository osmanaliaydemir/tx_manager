using System;
using System.Collections.Generic;

namespace TX_Manager.Application.DTOs;

public class AnalyticsSummaryDto
{
    public int Days { get; set; }

    public int TotalPosts { get; set; }
    public int DraftCount { get; set; }
    public int ScheduledCount { get; set; }
    public int PublishedCount { get; set; }
    public int FailedCount { get; set; }

    public long TotalImpressions { get; set; }
    public long TotalLikes { get; set; }
    public long TotalRetweets { get; set; }
    public long TotalReplies { get; set; }

    public double AvgImpressionsPerPublished { get; set; }
    public double AvgLikesPerPublished { get; set; }
    public double AvgRetweetsPerPublished { get; set; }
    public double AvgRepliesPerPublished { get; set; }

    public DateTime? LastMetricsUpdateUtc { get; set; }
}

public class AnalyticsTimeseriesPointDto
{
    public DateTime DateUtc { get; set; } // normalized day boundary in UTC (00:00)
    public int PublishedCount { get; set; }
    public long Impressions { get; set; }
    public long Likes { get; set; }
    public long Retweets { get; set; }
    public long Replies { get; set; }
}

public class AnalyticsTimeseriesDto
{
    public int Days { get; set; }
    public List<AnalyticsTimeseriesPointDto> Points { get; set; } = new();
}

public class AnalyticsTopPostDto
{
    public Guid Id { get; set; }
    public string ContentPreview { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public string? XPostId { get; set; }

    public int ImpressionCount { get; set; }
    public int LikeCount { get; set; }
    public int RetweetCount { get; set; }
    public int ReplyCount { get; set; }
}

public class AnalyticsTopPostsDto
{
    public int Days { get; set; }
    public string SortBy { get; set; } = "impressions"; // impressions|likes|retweets|replies
    public int Take { get; set; } = 10;
    public List<AnalyticsTopPostDto> Items { get; set; } = new();
}

