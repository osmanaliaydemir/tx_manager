using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace TX_Manager.Application.Common.Interfaces;

public class PushMessage
{
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public Dictionary<string, string> Data { get; set; } = new();
}

public interface IPushNotificationService
{
    Task NotifyPostPublishedAsync(Guid userId, Guid postId, string contentPreview);
    Task NotifyPostFailedAsync(Guid userId, Guid postId, string contentPreview, string? failureCode);
    Task NotifySuggestionsReadyAsync(Guid userId, int newCount);
}

