# Gizlilik Politikası (TX Asistan)

Son güncelleme: 2026-01-16

## 1) Kapsam
Bu gizlilik politikası, **TX Asistan** mobil uygulamasının (iOS/Android) kullanıcı verilerini nasıl işlediğini açıklar.

## 2) Toplanan Veriler
- **X (Twitter) hesabı kimliği / kullanıcı ID**: OAuth girişinden sonra uygulamayı kullanıcı hesabınla ilişkilendirmek için.
- **Tweet içerikleri**: Senin yazdığın tweet metinleri (taslak/planlama/thread).
- **Planlama bilgileri**: Tarih/saat, durum (taslak/zamanlandı/yayınlandı/başarısız) ve hata kodları.
- **Zaman dilimi bilgisi**: Cihazın time zone adı ve UTC offset (planlamayı doğru yapmak için).

## 3) Verilerin Kullanım Amaçları
- Tweet’lerini **taslak olarak kaydetmek**, **planlamak**, **yayınlamak**.
- Planlı içerikleri **takvimde göstermek**, **yeniden planlamak**.
- Yayın durumu ve hataları göstermek (örn. `RATE_LIMIT`, `TOKEN_REFRESH_FAILED`).

## 4) Verilerin Saklanması
- **Cihaz üzerinde lokal saklama**:
  - Zamanlanan post’lar için yerel cache (offline mod).
  - Şablonlar ve bildirim “tek sefer” kayıtları.
- **Sunucu tarafı (TX_Manager API)**:
  - Planlama kayıtları ve publish durumu (yukarıdaki amaçlar için).
  - OAuth token’ları **şifreli** saklanır.

## 5) Üçüncü Taraflar
- **X (Twitter) API**: OAuth ve tweet yayınlama.
- **(Opsiyonel) AI sağlayıcıları**: Uygulama içindeki ayarlara/özelliklere göre kullanılabilir (aktif edildiğinde).

## 6) Paylaşım
Kişisel verileri satmayız. Yasal zorunluluklar dışında üçüncü taraflarla paylaşmayız.

## 7) Güvenlik
- Sunucu tarafında token’lar şifreli saklanır.
- Mobil tarafta hassas bilgiler `flutter_secure_storage` ile saklanır.

## 8) Bildirimler
Uygulama, planlanan tweet’ler için hatırlatma ve yayınlama sonucu için cihazda **yerel bildirim** gösterebilir.

## 9) İletişim
Gizlilik ile ilgili talepler için: (buraya destek e-postanı ekle)

