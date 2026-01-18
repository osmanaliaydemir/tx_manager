using System;

namespace TX_Manager.Api.Auth;

public interface IJwtTokenService
{
    string CreateAccessToken(Guid userId);
}

