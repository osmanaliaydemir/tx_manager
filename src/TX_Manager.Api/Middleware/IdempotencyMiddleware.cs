using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using TX_Manager.Infrastructure.Persistence;
using TX_Manager.Infrastructure.Persistence.Entities;

namespace TX_Manager.Api.Middleware;

public class IdempotencyMiddleware
{
    public const string HeaderName = "Idempotency-Key";

    private readonly RequestDelegate _next;
    private readonly ILogger<IdempotencyMiddleware> _logger;

    public IdempotencyMiddleware(RequestDelegate next, ILogger<IdempotencyMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, AppDbContext db)
    {
        // Apply only to "write" verbs.
        var method = context.Request.Method?.ToUpperInvariant() ?? "";
        if (method is not ("POST" or "PUT" or "PATCH" or "DELETE"))
        {
            await _next(context);
            return;
        }

        if (!context.Request.Headers.TryGetValue(HeaderName, out var headerValues))
        {
            await _next(context);
            return;
        }

        var key = headerValues.FirstOrDefault()?.Trim();
        if (string.IsNullOrWhiteSpace(key))
        {
            await _next(context);
            return;
        }

        if (key.Length > 200)
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsync($"{HeaderName} too long (max 200).");
            return;
        }

        // Normalize request identity (ignore query string on purpose; key should be unique per semantic request).
        var path = context.Request.Path.Value ?? "/";

        // 1) If we already have a completed response, replay it.
        var existing = await db.IdempotencyRecords
            .AsNoTracking()
            .Where(r => r.Key == key && r.Method == method && r.Path == path)
            .FirstOrDefaultAsync(context.RequestAborted);

        if (existing is { IsCompleted: true })
        {
            context.Response.StatusCode = existing.StatusCode ?? StatusCodes.Status200OK;
            if (!string.IsNullOrWhiteSpace(existing.ContentType))
            {
                context.Response.ContentType = existing.ContentType;
            }

            if (!string.IsNullOrEmpty(existing.ResponseBody))
            {
                await context.Response.WriteAsync(existing.ResponseBody);
            }

            return;
        }

        // 2) Try to create a placeholder record. If concurrent request already created it,
        //    either replay (if completed) or tell the client to retry.
        if (existing is null)
        {
            try
            {
                db.IdempotencyRecords.Add(new IdempotencyRecord
                {
                    Key = key,
                    Method = method,
                    Path = path,
                    IsCompleted = false,
                    CreatedAtUtc = DateTime.UtcNow
                });

                await db.SaveChangesAsync(context.RequestAborted);
            }
            catch (DbUpdateException)
            {
                existing = await db.IdempotencyRecords
                    .AsNoTracking()
                    .Where(r => r.Key == key && r.Method == method && r.Path == path)
                    .FirstOrDefaultAsync(context.RequestAborted);

                if (existing is { IsCompleted: true })
                {
                    context.Response.StatusCode = existing.StatusCode ?? StatusCodes.Status200OK;
                    if (!string.IsNullOrWhiteSpace(existing.ContentType))
                    {
                        context.Response.ContentType = existing.ContentType;
                    }

                    if (!string.IsNullOrEmpty(existing.ResponseBody))
                    {
                        await context.Response.WriteAsync(existing.ResponseBody);
                    }

                    return;
                }

                context.Response.StatusCode = StatusCodes.Status409Conflict;
                context.Response.Headers["Retry-After"] = "1";
                await context.Response.WriteAsync("Request with same Idempotency-Key is in progress.");
                return;
            }
        }
        else
        {
            context.Response.StatusCode = StatusCodes.Status409Conflict;
            context.Response.Headers["Retry-After"] = "1";
            await context.Response.WriteAsync("Request with same Idempotency-Key is in progress.");
            return;
        }

        // 3) Execute request and capture response.
        var originalBody = context.Response.Body;
        await using var mem = new MemoryStream();
        context.Response.Body = mem;

        try
        {
            await _next(context);
        }
        finally
        {
            context.Response.Body = originalBody;
        }

        var bodyBytes = mem.ToArray();
        var bodyText = bodyBytes.Length == 0
            ? string.Empty
            : Encoding.UTF8.GetString(bodyBytes);

        // 4) Persist only for successful responses (avoid caching transient server faults).
        if (context.Response.StatusCode >= 200 && context.Response.StatusCode < 300)
        {
            try
            {
                var record = await db.IdempotencyRecords
                    .Where(r => r.Key == key && r.Method == method && r.Path == path)
                    .FirstOrDefaultAsync(context.RequestAborted);

                if (record != null && !record.IsCompleted)
                {
                    record.StatusCode = context.Response.StatusCode;
                    record.ContentType = context.Response.ContentType;
                    record.ResponseBody = bodyText;
                    record.IsCompleted = true;
                    record.CompletedAtUtc = DateTime.UtcNow;

                    await db.SaveChangesAsync(context.RequestAborted);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to persist idempotency record for {Method} {Path}", method, path);
            }
        }
        else
        {
            // Best-effort cleanup: keep record as non-completed to avoid replaying an error response.
            try
            {
                var record = await db.IdempotencyRecords
                    .Where(r => r.Key == key && r.Method == method && r.Path == path)
                    .FirstOrDefaultAsync(context.RequestAborted);

                if (record != null && !record.IsCompleted)
                {
                    db.IdempotencyRecords.Remove(record);
                    await db.SaveChangesAsync(context.RequestAborted);
                }
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Failed to cleanup idempotency placeholder for {Method} {Path}", method, path);
            }
        }

        // 5) Return captured response to client.
        if (bodyBytes.Length > 0)
        {
            await context.Response.Body.WriteAsync(bodyBytes, 0, bodyBytes.Length, context.RequestAborted);
        }
    }
}

