namespace TX_Manager.Application.Common.Time;

public class AutoScheduleOptions
{
    // Local hours in user's timezone.
    public int QuietHoursStartLocalHour { get; set; } = 23;
    public int QuietHoursEndLocalHour { get; set; } = 8;

    public int MinGapMinutes { get; set; } = 45;
    public int SlotMinutes { get; set; } = 15;
    public int MaxSearchDays { get; set; } = 30;
}

