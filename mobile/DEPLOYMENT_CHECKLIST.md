# 🚀 Deployment Checklist - Hızlı Başlangıç

## ⚡ Hızlı Komutlar

### iOS Build ve Upload
```bash
cd mobile
flutter clean
flutter pub get
flutter build ipa --release
# Sonra Xcode → Window → Organizer → Distribute App
```

### Android Build ve Upload
```bash
cd mobile
flutter clean
flutter pub get
flutter build appbundle --release
# Sonra Google Play Console'a upload
```

---

## 📋 Öncelikli Yapılacaklar

### 1. Android Signing Key Oluşturma (İLK KEZ - ÖNEMLİ!)

```bash
cd mobile/android

# Keystore oluştur
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Şifreleri ve bilgileri GÜVENLİ bir yerde saklayın!
```

**Sonra:**
1. `mobile/android/key.properties.example` dosyasını `key.properties` olarak kopyalayın
2. Gerçek değerleri girin
3. Keystore dosyasını güvenli bir yerde saklayın (yedekleyin!)

### 2. iOS Info.plist Production Ayarları

`mobile/ios/Runner/Info.plist` dosyasında:
```xml
<!-- Development için şu an true, production'da false yapılmalı -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>  <!-- Production'da false olmalı -->
</dict>
```

### 3. App Store Connect / Google Play Console

#### iOS:
- [ ] Apple Developer hesabı aktif mi?
- [ ] App Store Connect'te app oluşturuldu mu?
- [ ] Bundle ID kayıtlı mı?

#### Android:
- [ ] Google Play Developer hesabı oluşturuldu mu?
- [ ] Google Play Console'da app oluşturuldu mu?

---

## 📸 Gerekli Görseller

### iOS App Store
- [ ] App Icon: 1024x1024 PNG (✅ Var: `Icon-App-1024x1024@1x.png`)
- [ ] Screenshots: iPhone 6.7", 6.5", 5.5" boyutlarında
- [ ] iPad screenshots (opsiyonel)

### Google Play Store
- [ ] App Icon: 512x512 PNG
- [ ] Feature Graphic: 1024x500 PNG
- [ ] Phone Screenshots: En az 2 adet (16:9 veya 9:16)

---

## 🔐 Güvenlik Kontrolleri

- [ ] `key.properties` `.gitignore`'da mı? (✅ Eklendi)
- [ ] Keystore dosyası güvenli yerde mi?
- [ ] API keys ve secrets production'da doğru mu?
- [ ] Privacy Policy URL hazır mı?

---

## 📝 Store Listing Hazırlığı

### Gerekli Metinler:
- [ ] App açıklaması (kısa ve uzun)
- [ ] Keywords (iOS için)
- [ ] What's New / Release Notes
- [ ] Privacy Policy URL
- [ ] Support URL

---

## 🎯 Sonraki Adımlar

1. **Android**: Keystore oluştur → `key.properties` ayarla → Build al
2. **iOS**: Xcode'da signing ayarla → Build al → Upload
3. **Her İki Platform**: Store listing'i tamamla → Submit for review

Detaylı bilgi için: `APP_STORE_DEPLOYMENT.md` dosyasına bakın.
