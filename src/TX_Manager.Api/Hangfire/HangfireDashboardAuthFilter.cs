using System;
using System.Linq;
using System.Net;
using System.Text;
using Hangfire.Dashboard;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;

namespace TX_Manager.Api.Hangfire;

public class HangfireDashboardAuthFilter : IDashboardAuthorizationFilter
{
    private readonly IConfiguration _config;

    public HangfireDashboardAuthFilter(IConfiguration config)
    {
        _config = config;
    }

    public bool Authorize(DashboardContext context)
    {
        var http = context.GetHttpContext();

        // 1) IP allow-list (optional; localhost always allowed)
        var remoteIp = http.Connection.RemoteIpAddress;
        if (remoteIp != null && IPAddress.IsLoopback(remoteIp))
        {
            return true;
        }

        var allowedIps = _config.GetSection("Hangfire:Dashboard:AllowedIPs").Get<string[]>() ?? Array.Empty<string>();
        if (allowedIps.Length > 0)
        {
            var ipText = remoteIp?.ToString() ?? string.Empty;
            if (!allowedIps.Contains(ipText, StringComparer.OrdinalIgnoreCase))
            {
                return false;
            }
        }

        // 2) Basic auth (optional)
        var user = _config["Hangfire:Dashboard:Username"];
        var pass = _config["Hangfire:Dashboard:Password"];
        if (string.IsNullOrWhiteSpace(user) || string.IsNullOrWhiteSpace(pass))
        {
            // If not configured, allow only from allowed IPs (or localhost handled above)
            return allowedIps.Length > 0;
        }

        if (!http.Request.Headers.TryGetValue("Authorization", out var authHeader))
        {
            Challenge(http);
            return false;
        }

        var header = authHeader.ToString();
        if (!header.StartsWith("Basic ", StringComparison.OrdinalIgnoreCase))
        {
            Challenge(http);
            return false;
        }

        try
        {
            var encoded = header.Substring("Basic ".Length).Trim();
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(encoded));
            var parts = decoded.Split(':', 2);
            if (parts.Length != 2)
            {
                Challenge(http);
                return false;
            }

            var ok = parts[0] == user && parts[1] == pass;
            if (!ok) Challenge(http);
            return ok;
        }
        catch
        {
            Challenge(http);
            return false;
        }
    }

    private static void Challenge(HttpContext http)
    {
        http.Response.Headers["WWW-Authenticate"] = "Basic realm=\"Hangfire\"";
        http.Response.StatusCode = StatusCodes.Status401Unauthorized;
    }
}

