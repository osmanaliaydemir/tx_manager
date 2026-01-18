using System;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using TX_Manager.Application.Common.Interfaces;

namespace TX_Manager.Infrastructure.Services.Push;

public class PushNotificationService : IPushNotificationService
{
    private readonly IApplicationDbContext _db;
    private readonly IHttpClientFactory _http;
    private readonly ILogger<PushNotificationService> _logger;
    private readonly PushOptions _opts;

    public PushNotificationService(
        IApplicationDbContext db,
        IHttpClientFactory http,
        IOptions<PushOptions> opts,
        ILogger<PushNotificationService> logger)
    {
        _db = db;
        _http = http;
        _logger = logger;
        _opts = opts.Value ?? new PushOptions();
    }

    public Task NotifyPostPublishedAsync(Guid userId, Guid postId, string contentPreview)
    {
        return SendToUserAsync(userId, new PushMessage
        {
            Title = "Tweet yayınlandı",
            Body = contentPreview,
            Data = { ["type"] = "published", ["postId"] = postId.ToString() }
        });
    }

    public Task NotifyPostFailedAsync(Guid userId, Guid postId, string contentPreview, string? failureCode)
    {
        var body = string.IsNullOrWhiteSpace(failureCode) ? contentPreview : $"{failureCode}: {contentPreview}";
        return SendToUserAsync(userId, new PushMessage
        {
            Title = "Tweet başarısız",
            Body = body,
            Data = { ["type"] = "failed", ["postId"] = postId.ToString() }
        });
    }

    public Task NotifySuggestionsReadyAsync(Guid userId, int newCount)
    {
        return SendToUserAsync(userId, new PushMessage
        {
            Title = "AI önerileri hazır",
            Body = $"{newCount} yeni öneri var.",
            Data = { ["type"] = "suggestions_ready" }
        });
    }

    private async Task SendToUserAsync(Guid userId, PushMessage msg)
    {
        var tokens = await _db.DeviceTokens
            .AsNoTracking()
            .Where(d => d.UserId == userId && d.IsActive)
            .OrderByDescending(d => d.LastSeenAtUtc)
            .Select(d => d.Token)
            .Take(20)
            .ToListAsync();

        if (!tokens.Any())
        {
            _logger.LogInformation("Push: no tokens for user {UserId}", userId);
            return;
        }

        if (!_opts.Fcm.Enabled || string.IsNullOrWhiteSpace(_opts.Fcm.ServerKey))
        {
            _logger.LogInformation(
                "Push disabled/unconfigured. Would send to {TokenCount} tokens. Title={Title}",
                tokens.Count, msg.Title);
            return;
        }

        foreach (var t in tokens)
        {
            await SendFcmLegacyAsync(t, msg);
        }
    }

    private async Task SendFcmLegacyAsync(string token, PushMessage msg)
    {
        try
        {
            var client = _http.CreateClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("key", "=" + _opts.Fcm.ServerKey);

            var payload = new
            {
                to = token,
                notification = new { title = msg.Title, body = msg.Body },
                data = msg.Data
            };

            var json = JsonSerializer.Serialize(payload);
            var res = await client.PostAsync(
                _opts.Fcm.Endpoint,
                new StringContent(json, Encoding.UTF8, "application/json"));

            if (!res.IsSuccessStatusCode)
            {
                var body = await res.Content.ReadAsStringAsync();
                _logger.LogWarning("FCM push failed: {Status} {Body}", (int)res.StatusCode, body);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "FCM push exception");
        }
    }
}

