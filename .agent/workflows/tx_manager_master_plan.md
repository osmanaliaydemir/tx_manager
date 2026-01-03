---
description: TX Manager Master Implementation Plan
---

# TX Manager - Master Implementation Plan

Bu plan, "Otomatik Bot"tan "Stratejik İçerik Asistanı"na dönüşen TX Manager projesinin uygulama adımlarını içerir.

## ✅ Phase 0: Foundation (Tamamlandı)

- [x] .NET 9 Web API Kurulumu
- [x] MSSQL Veritabanı Bağlantısı
- [x] X (Twitter) OAuth 2.0 Entegrasyonu
- [x] Temel Varlıklar (`User`, `Post`, `AuthToken`)
- [x] Mobil Proje Kurulumu (Flutter + Riverpod)
- [x] Mobil Lokalizasyon Altyapısı (TR/EN)
- [x] Mobil Login Akışı (WebView + Deep Link + Secure Storage)
- [x] Strateji Varlıkları (`UserStrategy`, `ContentSuggestion`) DB Migrasyonu
- [x] Güvenlik: `.gitignore` ve `appsettings` düzenlemeleri.

## ✅ Phase 1: Onboarding & Calibration (Tamamlandı)

- [x] `IStrategyService` ve `StrategyService`
- [x] `StrategyController` (`GET/POST /api/strategy`)
- [x] Mobil: `Strategy` modeli ve `StrategyRepository`
- [x] Mobil: `OnboardingScreen` (Hedef ve Ton Seçimi)
- [x] Akıllı Yönlendirme (Strateji yoksa Onboarding'e, varsa Home'a)

## ✅ Phase 2: The Brain (AI Engine) (Tamamlandı)

- [x] `ILanguageModelProvider` ve `AIFactory` (OpenAI & Gemini Desteği)
- [x] `AIGeneratorService` (Strategy tabanlı içerik üretimi)
- [x] Prompt Mühendisliği: `System Prompt` tasarımı (Risk Analizi, Rationale dahil)
- [x] `POST /api/suggestion/generate/{userId}` endpoint'i
- [x] `GET /api/suggestion/{userId}` endpoint'i

## ✅ Phase 3: The Feed (Öneri Arayüzü) (Tamamlandı/MVP)

- [x] Mobil: `ContentSuggestion` entity ve repository
- [x] Mobil: `HomeScreen` tasarımı (Tinder-like Swipe UI - `flutter_card_swiper`)
- [x] Mobil: Glassmorphism & Neon UI Tasarımı
- [x] Backend: `POST /api/suggestion/{id}/accept` ve `reject` endpointleri
- [x] Backend: Kabul edilenleri otomatik `Scheduled` durumuna alma (Random saat atama - MVP için)
- [x] Mobil: Sağa/Sola kaydırarak API çağrıları yapma

## 🗓️ Phase 4: Execution & Scheduling (Sıradaki Adım)

**Hedef:** Onaylanan içeriklerin yayınlanması ve gerçek zamanlama mantığı.

### Backend

1. [ ] **Akıllı Zamanlama:** Öneriyi kabul ederken "Rastgele" yerine kullanıcının en iyi saatine (veya boş slotuna) yerleştirme mantığı.
2. [ ] **Background Job (Hangfire):** Dakikada bir çalışıp, `Status = Scheduled` ve `ScheduledTime <= Now` olan postları bulup X API'ye gönderen Job (`PostTweetJob`).
3. [ ] Hata Yönetimi: API limitleri veya başarısız gönderimler için Retry mekanizması.

### Mobile

1. [ ] **Calendar / Queue View:** Kullanıcının zamanlanmış gönderilerini görebileceği "Takvim" veya "Liste" ekranı.
2. [ ] **Edit Post:** Öneriyi kabul etmeden önce veya ettikten sonra metni düzenleyebilme.

## 📊 Phase 5: Feedback Loop (Analytics)

**Hedef:** AI'nin kendini geliştirmesi.

1. [ ] **Backend:** X API'den düzenli olarak etkileşim verilerini (Like, Repost, View) çeken Job.
2. [ ] **AI:** Yeni öneri üretirken, geçmişte yüksek performans gösteren içeriklerin tonunu/yapısını analiz et (Few-Shot Prompting).
3. [ ] **Mobile:** "Haftalık Özet" ekranı.

---
**Komut:** Proje GitHub'a gönderilmeye hazır. `.gitignore` yapılandırıldı ve hassas veriler temizlendi. Sonraki adım Phase 4'e geçmek.
