using System;

namespace TX_Manager.Infrastructure.Persistence.Entities;

public class IdempotencyRecord
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Key { get; set; } = string.Empty;
    public string Method { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;

    public bool IsCompleted { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAtUtc { get; set; }

    public int? StatusCode { get; set; }
    public string? ContentType { get; set; }
    public string? ResponseBody { get; set; }
}

