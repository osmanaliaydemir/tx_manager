using System;

namespace TX_Manager.Application.Common.Time;

public static class SchedulingTime
{
    /// <summary>
    /// Normalizes an incoming scheduled time to UTC and ensures it is not in the past.
    /// </summary>
    /// <remarks>
    /// - If <paramref name="scheduledFor"/> is Local, it is converted to UTC.
    /// - If it is Unspecified, it is treated as UTC (to avoid accidental double-offset).
    /// - If the resulting value is <= now, it is bumped slightly into the future so Hangfire can pick it up.
    /// </remarks>
    public static DateTime NormalizeToUtc(DateTime scheduledFor, DateTime utcNow)
    {
        DateTime utc = scheduledFor.Kind switch
        {
            DateTimeKind.Utc => scheduledFor,
            DateTimeKind.Local => scheduledFor.ToUniversalTime(),
            DateTimeKind.Unspecified => DateTime.SpecifyKind(scheduledFor, DateTimeKind.Utc),
            _ => DateTime.SpecifyKind(scheduledFor, DateTimeKind.Utc)
        };

        // If user scheduled in the past (or "now"), bump to a safe future moment.
        if (utc <= utcNow)
        {
            utc = utcNow.AddSeconds(5);
        }

        return utc;
    }

    /// <summary>
    /// Like <see cref="NormalizeToUtc(DateTime,DateTime)"/>, but can use the user's offset for Unspecified values.
    /// </summary>
    public static DateTime NormalizeToUtc(DateTime scheduledFor, DateTime utcNow, int? userOffsetMinutes)
    {
        if (scheduledFor.Kind != DateTimeKind.Unspecified)
        {
            return NormalizeToUtc(scheduledFor, utcNow);
        }

        DateTime utc;
        if (userOffsetMinutes.HasValue)
        {
            // Interpret the Unspecified clock time as "user local time" with a fixed offset.
            // Note: This does not model DST transitions; for that we'd need an IANA zone id.
            var offset = TimeSpan.FromMinutes(userOffsetMinutes.Value);
            var unspecified = DateTime.SpecifyKind(scheduledFor, DateTimeKind.Unspecified);
            utc = new DateTimeOffset(unspecified, offset).UtcDateTime;
        }
        else
        {
            // Fallback: treat as UTC to avoid accidental double-offset.
            utc = DateTime.SpecifyKind(scheduledFor, DateTimeKind.Utc);
        }

        if (utc <= utcNow)
        {
            utc = utcNow.AddSeconds(5);
        }

        return utc;
    }
}

