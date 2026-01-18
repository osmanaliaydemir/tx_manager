class AnalyticsSummary {
  final int days;
  final int totalPosts;
  final int draftCount;
  final int scheduledCount;
  final int publishedCount;
  final int failedCount;

  final int totalImpressions;
  final int totalLikes;
  final int totalRetweets;
  final int totalReplies;

  final double avgImpressionsPerPublished;
  final double avgLikesPerPublished;
  final double avgRetweetsPerPublished;
  final double avgRepliesPerPublished;

  final DateTime? lastMetricsUpdateUtc;

  AnalyticsSummary({
    required this.days,
    required this.totalPosts,
    required this.draftCount,
    required this.scheduledCount,
    required this.publishedCount,
    required this.failedCount,
    required this.totalImpressions,
    required this.totalLikes,
    required this.totalRetweets,
    required this.totalReplies,
    required this.avgImpressionsPerPublished,
    required this.avgLikesPerPublished,
    required this.avgRetweetsPerPublished,
    required this.avgRepliesPerPublished,
    required this.lastMetricsUpdateUtc,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return AnalyticsSummary(
      days: (json['days'] ?? 0) as int,
      totalPosts: (json['totalPosts'] ?? 0) as int,
      draftCount: (json['draftCount'] ?? 0) as int,
      scheduledCount: (json['scheduledCount'] ?? 0) as int,
      publishedCount: (json['publishedCount'] ?? 0) as int,
      failedCount: (json['failedCount'] ?? 0) as int,
      totalImpressions: (json['totalImpressions'] ?? 0) as int,
      totalLikes: (json['totalLikes'] ?? 0) as int,
      totalRetweets: (json['totalRetweets'] ?? 0) as int,
      totalReplies: (json['totalReplies'] ?? 0) as int,
      avgImpressionsPerPublished: (json['avgImpressionsPerPublished'] ?? 0)
          .toDouble(),
      avgLikesPerPublished: (json['avgLikesPerPublished'] ?? 0).toDouble(),
      avgRetweetsPerPublished: (json['avgRetweetsPerPublished'] ?? 0)
          .toDouble(),
      avgRepliesPerPublished: (json['avgRepliesPerPublished'] ?? 0).toDouble(),
      lastMetricsUpdateUtc: parseDt(json['lastMetricsUpdateUtc']),
    );
  }
}

class AnalyticsTimeseriesPoint {
  final DateTime dateUtc;
  final int publishedCount;
  final int impressions;
  final int likes;
  final int retweets;
  final int replies;

  AnalyticsTimeseriesPoint({
    required this.dateUtc,
    required this.publishedCount,
    required this.impressions,
    required this.likes,
    required this.retweets,
    required this.replies,
  });

  factory AnalyticsTimeseriesPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsTimeseriesPoint(
      dateUtc: DateTime.parse(json['dateUtc'].toString()),
      publishedCount: (json['publishedCount'] ?? 0) as int,
      impressions: (json['impressions'] ?? 0) as int,
      likes: (json['likes'] ?? 0) as int,
      retweets: (json['retweets'] ?? 0) as int,
      replies: (json['replies'] ?? 0) as int,
    );
  }
}

class AnalyticsTimeseries {
  final int days;
  final List<AnalyticsTimeseriesPoint> points;

  AnalyticsTimeseries({required this.days, required this.points});

  factory AnalyticsTimeseries.fromJson(Map<String, dynamic> json) {
    final items = (json['points'] as List?) ?? const [];
    return AnalyticsTimeseries(
      days: (json['days'] ?? 0) as int,
      points: items
          .whereType<Map>()
          .map(
            (m) =>
                AnalyticsTimeseriesPoint.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList(),
    );
  }
}

class AnalyticsTopPost {
  final String id;
  final String contentPreview;
  final DateTime createdAtUtc;
  final String? xPostId;
  final int impressionCount;
  final int likeCount;
  final int retweetCount;
  final int replyCount;

  AnalyticsTopPost({
    required this.id,
    required this.contentPreview,
    required this.createdAtUtc,
    required this.xPostId,
    required this.impressionCount,
    required this.likeCount,
    required this.retweetCount,
    required this.replyCount,
  });

  factory AnalyticsTopPost.fromJson(Map<String, dynamic> json) {
    return AnalyticsTopPost(
      id: json['id'].toString(),
      contentPreview: (json['contentPreview'] ?? '').toString(),
      createdAtUtc: DateTime.parse(json['createdAtUtc'].toString()),
      xPostId: json['xPostId']?.toString(),
      impressionCount: (json['impressionCount'] ?? 0) as int,
      likeCount: (json['likeCount'] ?? 0) as int,
      retweetCount: (json['retweetCount'] ?? 0) as int,
      replyCount: (json['replyCount'] ?? 0) as int,
    );
  }
}

class AnalyticsTopPosts {
  final int days;
  final String sortBy;
  final int take;
  final List<AnalyticsTopPost> items;

  AnalyticsTopPosts({
    required this.days,
    required this.sortBy,
    required this.take,
    required this.items,
  });

  factory AnalyticsTopPosts.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?) ?? const [];
    return AnalyticsTopPosts(
      days: (json['days'] ?? 0) as int,
      sortBy: (json['sortBy'] ?? 'impressions').toString(),
      take: (json['take'] ?? 0) as int,
      items: items
          .whereType<Map>()
          .map((m) => AnalyticsTopPost.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}
