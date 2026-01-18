using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Application.Common.Time;
using TX_Manager.Application.DTOs;
using TX_Manager.Domain.Entities;
using TX_Manager.Domain.Enums;

namespace TX_Manager.Application.Services;

public class SuggestionService : ISuggestionService
{
    private readonly IApplicationDbContext _db;
    private readonly AutoScheduleOptions _opts;

    public SuggestionService(IApplicationDbContext db, IOptions<AutoScheduleOptions> opts)
    {
        _db = db;
        _opts = opts.Value ?? new AutoScheduleOptions();
    }

    public async Task<SuggestionListResponseDto> GetSuggestionsAsync(
        Guid userId,
        SuggestionStatus? status,
        string? cursor,
        int take)
    {
        take = Math.Clamp(take, 1, 50);

        var q = _db.ContentSuggestions
            .AsNoTracking()
            .Where(s => s.UserId == userId);

        if (status.HasValue)
        {
            q = q.Where(s => s.Status == status.Value);
        }

        // Cursor: base64("ticks|guid") where ticks represent GeneratedAtUtc ticks.
        if (!string.IsNullOrWhiteSpace(cursor) && TryDecodeCursor(cursor, out var cursorAtUtc, out var cursorId))
        {
            q = q.Where(s => s.GeneratedAt < cursorAtUtc || (s.GeneratedAt == cursorAtUtc && s.Id.CompareTo(cursorId) < 0));
        }

        var items = await q
            .OrderByDescending(s => s.GeneratedAt)
            .ThenByDescending(s => s.Id)
            .Take(take)
            .Select(s => new SuggestionItemDto
            {
                Id = s.Id,
                SuggestedText = s.SuggestedText,
                Rationale = s.Rationale,
                RiskAssessment = s.RiskAssessment,
                EstimatedImpact = s.EstimatedImpact,
                Status = s.Status,
                GeneratedAtUtc = s.GeneratedAt
            })
            .ToListAsync();

        string? nextCursor = null;
        if (items.Count == take)
        {
            var last = items.Last();
            nextCursor = EncodeCursor(last.GeneratedAtUtc, last.Id);
        }

        return new SuggestionListResponseDto { Items = items, NextCursor = nextCursor };
    }

    public async Task<AcceptSuggestionResponseDto> AcceptAsync(Guid userId, Guid suggestionId, AcceptSuggestionRequestDto request)
    {
        var suggestion = await _db.ContentSuggestions
            .Include(s => s.ScheduledPost)
            .FirstOrDefaultAsync(s => s.Id == suggestionId && s.UserId == userId);

        if (suggestion == null) throw new KeyNotFoundException("Suggestion not found.");
        if (suggestion.Status != SuggestionStatus.Pending) throw new InvalidOperationException("Suggestion is not pending.");

        var scheduledForUtc = request.Mode switch
        {
            AcceptMode.Manual => request.ScheduledForUtc ?? throw new InvalidOperationException("scheduledForUtc is required for Manual mode."),
            AcceptMode.Auto => await ComputeAutoScheduleUtcAsync(userId, request.SchedulePolicy),
            _ => await ComputeAutoScheduleUtcAsync(userId, request.SchedulePolicy)
        };

        if (scheduledForUtc <= DateTime.UtcNow.AddMinutes(1))
        {
            throw new InvalidOperationException("Scheduled time must be in the future.");
        }

        var post = new Post
        {
            UserId = userId,
            Content = suggestion.SuggestedText,
            ScheduledFor = scheduledForUtc,
            Status = PostStatus.Scheduled,
            CreatedAt = DateTime.UtcNow
        };

        _db.Posts.Add(post);
        suggestion.Status = SuggestionStatus.Accepted;
        suggestion.ScheduledPost = post;

        await _db.SaveChangesAsync();

        return new AcceptSuggestionResponseDto { PostId = post.Id, ScheduledForUtc = scheduledForUtc };
    }

    public async Task RejectAsync(Guid userId, Guid suggestionId, string? reason)
    {
        var suggestion = await _db.ContentSuggestions
            .FirstOrDefaultAsync(s => s.Id == suggestionId && s.UserId == userId);

        if (suggestion == null) throw new KeyNotFoundException("Suggestion not found.");
        if (suggestion.Status != SuggestionStatus.Pending) throw new InvalidOperationException("Suggestion is not pending.");

        suggestion.Status = SuggestionStatus.Rejected;
        suggestion.RejectionReason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();
        suggestion.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
    }

    private async Task<DateTime> ComputeAutoScheduleUtcAsync(Guid userId, SchedulePolicyDto? policy)
    {
        var user = await _db.Users
            .AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => new { u.TimeZoneOffsetMinutes })
            .FirstOrDefaultAsync();

        var strategy = await _db.UserStrategies
            .AsNoTracking()
            .Where(s => s.UserId == userId)
            .Select(s => new { s.PostsPerDay })
            .FirstOrDefaultAsync();

        var offsetMinutes = user?.TimeZoneOffsetMinutes ?? 0;
        var dailyCap = Math.Clamp(strategy?.PostsPerDay ?? 3, 1, 50);

        var nowUtc = DateTime.UtcNow;
        var localNow = nowUtc.AddMinutes(offsetMinutes);
        var slotMinutes = Math.Clamp(_opts.SlotMinutes, 1, 60);

        // Start from next slot (>= now + 1 minute).
        var candidateLocal = RoundUp(localNow.AddMinutes(1), slotMinutes);

        for (var day = 0; day < Math.Clamp(_opts.MaxSearchDays, 1, 365); day++)
        {
            var localDate = candidateLocal.Date.AddDays(day == 0 ? 0 : 1);
            if (day > 0)
            {
                candidateLocal = localDate.AddHours(_opts.QuietHoursEndLocalHour);
            }

            var localDayStart = candidateLocal.Date;

            if (policy?.ExcludeWeekends == true)
            {
                // Skip Saturday/Sunday in user's local calendar
                if (localDayStart.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday)
                {
                    candidateLocal = localDayStart.AddDays(1).AddHours(_opts.QuietHoursEndLocalHour);
                    continue;
                }
            }

            var dayStartUtc = localDayStart.AddMinutes(-offsetMinutes);
            var dayEndUtc = dayStartUtc.AddDays(1);

            var scheduledCount = await _db.Posts
                .AsNoTracking()
                .Where(p => p.UserId == userId
                            && p.Status == PostStatus.Scheduled
                            && p.ScheduledFor != null
                            && p.ScheduledFor >= dayStartUtc
                            && p.ScheduledFor < dayEndUtc)
                .CountAsync();

            if (scheduledCount >= dailyCap)
            {
                // Try next day.
                candidateLocal = localDayStart.AddDays(1).AddHours(_opts.QuietHoursEndLocalHour);
                continue;
            }

            // Search within this day.
            var minGap = Math.Clamp(_opts.MinGapMinutes, 0, 24 * 60);
            var dayEndLocalExclusive = localDayStart.AddDays(1);

            while (candidateLocal < dayEndLocalExclusive)
            {
                candidateLocal = SkipQuietHours(candidateLocal, localDayStart);
                candidateLocal = ApplyPreferredWindow(candidateLocal, localDayStart, policy);
                if (candidateLocal >= dayEndLocalExclusive) break;

                var candidateUtc = candidateLocal.AddMinutes(-offsetMinutes);
                var windowStartUtc = candidateUtc.AddMinutes(-minGap);
                var windowEndUtc = candidateUtc.AddMinutes(minGap);

                var conflict = await _db.Posts
                    .AsNoTracking()
                    .Where(p => p.UserId == userId
                                && p.Status == PostStatus.Scheduled
                                && p.ScheduledFor != null
                                && p.ScheduledFor >= windowStartUtc
                                && p.ScheduledFor <= windowEndUtc)
                    .AnyAsync();

                if (!conflict)
                {
                    return candidateUtc;
                }

                candidateLocal = candidateLocal.AddMinutes(slotMinutes);
            }
        }

        // Fallback: tomorrow at quiet-end
        var fallbackLocal = localNow.Date.AddDays(1).AddHours(_opts.QuietHoursEndLocalHour);
        return fallbackLocal.AddMinutes(-offsetMinutes);
    }

    private DateTime ApplyPreferredWindow(DateTime local, DateTime localDayStart, SchedulePolicyDto? policy)
    {
        if (policy == null) return local;
        if (policy.PreferredStartLocalHour == null || policy.PreferredEndLocalHour == null) return local;

        var start = Math.Clamp(policy.PreferredStartLocalHour.Value, 0, 23);
        var end = Math.Clamp(policy.PreferredEndLocalHour.Value, 0, 23);
        if (start == end) return local; // treat as "no constraint"

        // Interpret as [start, end) on the same day (no wrap). If wrap, also treat as no constraint for MVP.
        if (start > end) return local;

        var h = local.Hour;
        if (h < start)
        {
            return localDayStart.AddHours(start);
        }
        if (h >= end)
        {
            // Move to next day start of preferred window
            return localDayStart.AddDays(1).AddHours(start);
        }
        return local;
    }

    private DateTime SkipQuietHours(DateTime local, DateTime localDayStart)
    {
        var start = Math.Clamp(_opts.QuietHoursStartLocalHour, 0, 23);
        var end = Math.Clamp(_opts.QuietHoursEndLocalHour, 0, 23);

        var h = local.Hour;
        var inQuiet = start == end
            ? false
            : (start < end ? (h >= start && h < end) : (h >= start || h < end));

        if (!inQuiet) return local;

        // If quiet wraps midnight (e.g. 23->8), and we are after start (23..23:59), move to next day's end hour.
        if (start > end && h >= start)
        {
            return localDayStart.AddDays(1).AddHours(end);
        }

        // Otherwise move to today's end hour.
        return localDayStart.AddHours(end);
    }

    private static DateTime RoundUp(DateTime dt, int minutes)
    {
        if (minutes <= 1) return new DateTime(dt.Ticks, dt.Kind);
        var delta = minutes * TimeSpan.TicksPerMinute;
        var rounded = ((dt.Ticks + delta - 1) / delta) * delta;
        return new DateTime(rounded, dt.Kind);
    }

    private static string EncodeCursor(DateTime generatedAtUtc, Guid id)
        => Convert.ToBase64String(Encoding.UTF8.GetBytes($"{generatedAtUtc.Ticks}|{id}"));

    private static bool TryDecodeCursor(string cursor, out DateTime generatedAtUtc, out Guid id)
    {
        generatedAtUtc = default;
        id = default;

        try
        {
            var raw = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var parts = raw.Split('|', 2);
            if (parts.Length != 2) return false;
            if (!long.TryParse(parts[0], out var ticks)) return false;
            if (!Guid.TryParse(parts[1], out id)) return false;
            generatedAtUtc = new DateTime(ticks, DateTimeKind.Utc);
            return true;
        }
        catch
        {
            return false;
        }
    }
}

