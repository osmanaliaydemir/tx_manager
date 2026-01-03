using System;
using System.Text;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using Microsoft.Extensions.Configuration;
using TX_Manager.Application.Common.Interfaces;

namespace TX_Manager.Infrastructure.Services;

public class TokenEncryptionService : ITokenEncryptionService
{
    private readonly string _aesKey;

    public TokenEncryptionService(IConfiguration configuration)
    {
        // 32 chars for AES-256
        _aesKey = configuration["Encryption:AesKey"] 
                  ?? Environment.GetEnvironmentVariable("ENCRYPTION_KEY") 
                  ?? "DEFAULT_KEY_FOR_DEV_ONLY_12345678"; 
    }

    public string Encrypt(string value)
    {
        if (string.IsNullOrEmpty(value)) return value;

        // Try DPAPI on Windows
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            try 
            {
                byte[] data = Encoding.UTF8.GetBytes(value);
                byte[] encrypted = ProtectedData.Protect(data, null, DataProtectionScope.CurrentUser);
                return "DPAPI:" + Convert.ToBase64String(encrypted);
            }
            catch 
            { 
                // Fallback to AES if DPAPI fails
            }
        }

        // AES Fallback
        return "AES:" + EncryptAes(value);
    }

    public string Decrypt(string value)
    {
        if (string.IsNullOrEmpty(value)) return value;

        if (value.StartsWith("DPAPI:"))
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                string payload = value.Substring("DPAPI:".Length);
                byte[] data = Convert.FromBase64String(payload);
                byte[] decrypted = ProtectedData.Unprotect(data, null, DataProtectionScope.CurrentUser);
                return Encoding.UTF8.GetString(decrypted);
            }
            else
            {
                throw new PlatformNotSupportedException("Cannot decrypt DPAPI data on non-Windows platform.");
            }
        }
        else if (value.StartsWith("AES:"))
        {
            return DecryptAes(value.Substring("AES:".Length));
        }

        // Assume plain text or unknown format (legacy)
        return value;
    }

    private string EncryptAes(string plainText)
    {
        byte[] key = Encoding.UTF8.GetBytes(_aesKey.PadRight(32).Substring(0, 32));
        byte[] iv = new byte[16]; // Use random IV in production and prepend it
        // For simplicity in this example, using static IV or generating it. 
        // Best practice: Generate IV, prepend to ciphertext.
        
        using (Aes aes = Aes.Create())
        {
            aes.Key = key;
            aes.GenerateIV();
            iv = aes.IV;

            ICryptoTransform encryptor = aes.CreateEncryptor(aes.Key, aes.IV);

            using (var msEncrypt = new System.IO.MemoryStream())
            {
                using (var csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write))
                using (var swEncrypt = new System.IO.StreamWriter(csEncrypt))
                {
                    swEncrypt.Write(plainText);
                }
                
                var encryptedContent = msEncrypt.ToArray();
                var result = new byte[iv.Length + encryptedContent.Length];
                Buffer.BlockCopy(iv, 0, result, 0, iv.Length);
                Buffer.BlockCopy(encryptedContent, 0, result, iv.Length, encryptedContent.Length);
                
                return Convert.ToBase64String(result);
            }
        }
    }

    private string DecryptAes(string cipherText)
    {
        // Safe check for IV
        byte[] fullCipher = Convert.FromBase64String(cipherText);
        if (fullCipher.Length < 16) throw new ArgumentException("Invalid cipher text");

        byte[] key = Encoding.UTF8.GetBytes(_aesKey.PadRight(32).Substring(0, 32));
        
        using (Aes aes = Aes.Create())
        {
            byte[] iv = new byte[16];
            byte[] cipher = new byte[fullCipher.Length - 16];
            
            Buffer.BlockCopy(fullCipher, 0, iv, 0, 16);
            Buffer.BlockCopy(fullCipher, 16, cipher, 0, cipher.Length);
            
            aes.Key = key;
            aes.IV = iv;

            ICryptoTransform decryptor = aes.CreateDecryptor(aes.Key, aes.IV);

            using (var msDecrypt = new System.IO.MemoryStream(cipher))
            using (var csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
            using (var srDecrypt = new System.IO.StreamReader(csDecrypt))
            {
                return srDecrypt.ReadToEnd();
            }
        }
    }
}
