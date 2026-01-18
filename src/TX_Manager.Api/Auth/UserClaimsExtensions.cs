using System;
using System.Security.Claims;

namespace TX_Manager.Api.Auth;

public static class UserClaimsExtensions
{
    public static Guid GetUserId(this ClaimsPrincipal user)
    {
        var idText =
            user.FindFirstValue(ClaimTypes.NameIdentifier) ??
            user.FindFirstValue("sub");

        if (Guid.TryParse(idText, out var id))
        {
            return id;
        }

        throw new InvalidOperationException("UserId claim missing or invalid.");
    }
}

