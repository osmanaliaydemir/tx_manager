using System.Threading.Tasks;

namespace TX_Manager.Application.Common.Interfaces;

public interface ILanguageModelProvider
{
    // The core method every AI provider must implement
    Task<string> GenerateTextAsync(string prompt, string systemInstruction = "");
}
