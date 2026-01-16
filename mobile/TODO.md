# TODO / Roadmap (TX Asistan)

## 1) Yayınlama güvenilirliği (Backend + Mobile)
- [x] **Retry mekanizması**: “Başarısız” tweette tek tuşla “yeniden dene” (status tekrar Scheduled + yakın zamana al).
- [x] **Publish öncesi health-check**: token var mı / expire mı / refresh mümkün mü; kullanıcıya net uyarı.
- [x] **Queue / concurrency kontrolü**: job overlap engelleme (Hangfire `DisableConcurrentExecution`) + retry’de failure alanlarını temizleme.

## 2) Zamanlama & Saat dilimi
- [x] **UTC normalize (backend)**: ScheduledFor değerini UTC’ye normalize et + geçmiş tarih guard.
- [x] **Mobile guard + görünürlük**: geçmiş saate planlamayı engelle + ekran üzerinde saat dilimi bilgisi göster.
- [x] **Unit test**: NormalizeToUtc için temel senaryolar (Utc/Unspecified/Past) test edildi.
- [x] **Kullanıcı timezone kaydı**: backend’de user timezone (name + offset) sakla; login sonrası mobil otomatik gönderir.
- [x] **DST/locale edge-case testleri (kısmi)**: legacy client “Unspecified” saatleri için user offset ile UTC’ye çevirme + unit test.
- [x] **Takvim görünümü**: ay/hafta/gün görünümü + badge/sayı + güne göre filtre + sürükle-bırak ile yeniden planla (drop’ta “saati koru / saat seç”) + **gün timeline (saat slotlarına drop)**.

## 3) UX – Tweet yazma
- [x] **Karakter sayacı + uyarı**: 280 yaklaşınca renk değişimi / engelleme.
- [x] **Thread desteği**: birden fazla tweet’i zincir olarak planla.
- [x] **Draft’lar**: taslak kaydet / taslaklardan seç.
- [x] **Şablonlar**: sık kullanılan tweet formatları (local).

## 4) Bildirimler
- [x] **Local push**: “Tweet yayınlandı”, “Tweet başarısız oldu” + planlanan tweet için 5 dk önce hatırlatma.
- [x] **Onay akışı (MVP)**: “Yayınlamadan 5 dk önce haber ver → iptal/ertele” (bildirime tıkla → `/approval`).

## 5) Observability (Backend)
- [x] **Hangfire dashboard güvenliği**: Basic auth + IP allow-list.
- [x] **Structured logging**: publish attempt id, userId, postId, latency + run summary.
- [x] **Admin endpoint**: son publish run sonucu (counts + timestamps).

## 6) Veri modeli & API iyileştirmeleri
- [x] **Status alanı standardı**: backend `Status` string yerine enum int döndürsün (mobile parsing sadeleşir).
- [x] **FailureReason standardizasyonu**: hata kodu + mesaj (`TOKEN_MISSING`, `TOKEN_REFRESH_FAILED`, `RATE_LIMIT`, `X_API_ERROR`, ...).
- [x] **Idempotency**: aynı scheduled post/thread’in iki kez gönderilmesini engelle (DB publish lock + head-of-thread claim).

## 7) Mobil local cache / offline
- [x] **Offline mod**: planlamaları lokalden göster, internet gelince sync (Scheduled cache-first provider).
- [x] **Optimistic UI**: planla basınca listede anında göster; server response ile finalize et (local-temp id + reconcile).

## 8) Güvenlik
- [x] **Prod için HttpOverrides kaldırma**: self-signed bypass kapat (release build’te devre dışı).
- [x] **Token saklama & refresh flow**: refresh token yoksa `TOKEN_REFRESH_MISSING` ile fail + log.

## 9) App Store hazırlıkları
- [x] **Launch screen özelleştir**: LaunchImage + storyboard güncellendi (placeholder launch image kaldırıldı).
- [x] **Privacy Policy + Data Safety metinleri**: `PRIVACY_POLICY.md` + `STORE_LISTING.md` + iOS `PrivacyInfo.xcprivacy`.
- [x] **TestFlight süreci**: `IOS_DEPLOYMENT.md` içinde pratik akış + release IPA build doğrulaması.

