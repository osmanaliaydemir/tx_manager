using TX_Manager.Application.Common.Time;

namespace TX_Manager.UnitTests;

public class SchedulingTimeTests
{
    [Fact]
    public void NormalizeToUtc_WhenUtc_PreservesUtc()
    {
        var now = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
        var input = new DateTime(2026, 1, 1, 13, 0, 0, DateTimeKind.Utc);

        var result = SchedulingTime.NormalizeToUtc(input, now);

        Assert.Equal(DateTimeKind.Utc, result.Kind);
        Assert.Equal(input, result);
    }

    [Fact]
    public void NormalizeToUtc_WhenUnspecified_TreatsAsUtc()
    {
        var now = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
        var input = new DateTime(2026, 1, 1, 13, 0, 0, DateTimeKind.Unspecified);

        var result = SchedulingTime.NormalizeToUtc(input, now);

        Assert.Equal(DateTimeKind.Utc, result.Kind);
        Assert.Equal(new DateTime(2026, 1, 1, 13, 0, 0, DateTimeKind.Utc), result);
    }

    [Fact]
    public void NormalizeToUtc_WhenPast_BumpsToFuture()
    {
        var now = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
        var input = new DateTime(2026, 1, 1, 11, 59, 0, DateTimeKind.Utc);

        var result = SchedulingTime.NormalizeToUtc(input, now);

        Assert.True(result > now);
    }

    [Fact]
    public void NormalizeToUtc_WhenUnspecified_WithOffset_ConvertsUsingOffset()
    {
        // 14:00 at UTC+3 should be 11:00Z
        var now = new DateTime(2026, 1, 1, 10, 0, 0, DateTimeKind.Utc);
        var input = new DateTime(2026, 1, 1, 14, 0, 0, DateTimeKind.Unspecified);

        var result = SchedulingTime.NormalizeToUtc(input, now, userOffsetMinutes: 180);

        Assert.Equal(DateTimeKind.Utc, result.Kind);
        Assert.Equal(new DateTime(2026, 1, 1, 11, 0, 0, DateTimeKind.Utc), result);
    }
}
