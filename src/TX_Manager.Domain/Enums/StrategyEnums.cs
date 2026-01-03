using System.ComponentModel.DataAnnotations;

namespace TX_Manager.Domain.Enums;

public enum StrategyGoal
{
    Authority,      // Bilgi/Otorite
    Engagement,     // Etkileşim/Tartışma
    Community,      // Topluluk/Samimiyet
    Sales           // Satış/Dönüşüm
}

public enum ToneVoice
{
    Professional,   // Kurumsal
    Friendly,       // Arkadaşçıl
    Witty,          // Espritüel/Hazırcevap
    Minimalist,     // Az ve öz
    Provocative     // Cesur
}
