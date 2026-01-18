namespace TX_Manager.Api.Auth;

public class JwtOptions
{
    public string Issuer { get; set; } = "TX_Manager";
    public string Audience { get; set; } = "TX_Manager.Mobile";

    // Symmetric key for HS256. Keep in secrets/env in real deployments.
    public string SigningKey { get; set; } = "CHANGE_ME_TO_A_LONG_RANDOM_SECRET";

    public int AccessTokenMinutes { get; set; } = 60 * 24 * 7; // 7 days (MVP)
}

