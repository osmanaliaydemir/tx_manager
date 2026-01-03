namespace TX_Manager.Application.Common.Interfaces;

public interface ITokenEncryptionService
{
    string Encrypt(string value);
    string Decrypt(string value);
}
