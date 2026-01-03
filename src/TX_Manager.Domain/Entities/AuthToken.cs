using System;

namespace TX_Manager.Domain.Entities;

public class AuthToken : BaseEntity
{
    public Guid UserId { get; set; }
    public User? User { get; set; }

    // These should be stored encrypted
    public string EncryptedAccessToken { get; set; } = string.Empty;
    public string EncryptedRefreshToken { get; set; } = string.Empty;
    
    public DateTime ExpiresAt { get; set; }
}
