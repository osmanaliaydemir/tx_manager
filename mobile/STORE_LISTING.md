# Store Listing / Data Safety Notları (TX Asistan)

## iOS (App Store Connect)
- **App Name**: TX Asistan
- **Support URL**: (buraya koy)
- **Privacy Policy URL**: `PRIVACY_POLICY.md`’yi bir web sayfası olarak yayınlayıp URL ver
- **Privacy Manifest**: `ios/Runner/PrivacyInfo.xcprivacy`

### App Review Notu (öneri)
Uygulama X (Twitter) OAuth ile giriş yapar ve planlanan tweet’leri belirtilen zamanda yayınlar. Planlamalar takvim ekranından düzenlenebilir/iptal edilebilir.

## Android (Google Play – Data Safety)
### Toplanan veriler (örnek beyan)
- **User ID / Account**: X OAuth sonrası kullanıcı id ilişkilendirmesi
- **User content**: Tweet içerikleri (taslak/planlama/thread)
- **Diagnostics**: (eğer eklenirse) crash / log

### Paylaşım
- Satılmaz / reklam tracking yok (mevcut uygulama tasarımına göre).

### İşleme amaçları
- App functionality (planlama + yayınlama)

Not: Play Console’daki Data Safety ekranında “collect/share” ve “encrypted in transit/at rest” sorularını uygulamanın gerçek davranışına göre doldur.

