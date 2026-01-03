using System;

namespace TX_Manager.Application.Common.Models;

public class XAuthResult
{
    public string AccessToken { get; set; } = string.Empty;
    public string? RefreshToken { get; set; }
    public int ExpiresIn { get; set; } // Seconds
}
