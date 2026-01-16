using System;

namespace TX_Manager.Application.Common.Models;

public class PublishRunResult
{
    public DateTime StartedAtUtc { get; set; }
    public DateTime FinishedAtUtc { get; set; }
    public int HeadsDue { get; set; }
    public int HeadsClaimed { get; set; }
    public int PostsAttempted { get; set; }
    public int PostsPublished { get; set; }
    public int PostsFailed { get; set; }
    public int SkippedLocked { get; set; }
}

