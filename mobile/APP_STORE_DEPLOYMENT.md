# App Store ve Google Play Store Yükleme Rehberi

## 📱 Genel Bilgiler

- **App Adı**: TX Asistan
- **iOS Bundle ID**: `com.turhibun.txManagerMobile`
- **Android Package**: `com.turhibun.tx_manager_mobile`
- **Mevcut Versiyon**: 1.0.0+1

---

## 🍎 iOS App Store Yükleme Adımları

### 1. Ön Hazırlık

#### 1.1 Apple Developer Hesabı
- [Apple Developer Program](https://developer.apple.com/programs/) üyeliği gerekli ($99/yıl)
- App Store Connect hesabı oluşturulmalı

#### 1.2 Gerekli Araçlar
```bash
# Xcode yüklü olmalı (Mac gerekli)
# CocoaPods yüklü olmalı
sudo gem install cocoapods
```

### 2. Xcode Yapılandırması

#### 2.1 Bundle Identifier Kontrolü
- Xcode'da `Runner.xcodeproj` açın
- Target: Runner → General → Bundle Identifier: `com.turhibun.txManagerMobile`
- Signing & Capabilities sekmesinde:
  - **Automatically manage signing** işaretli olmalı
  - **Team** seçilmeli (Apple Developer hesabınız)

#### 2.2 Capabilities Ekleme (Gerekirse)
- Signing & Capabilities → + Capability
- Gerekli capability'ler:
  - **Associated Domains** (deep linking için)
  - **Background Modes** (push notifications için, şu an gerekli değil)

#### 2.3 Info.plist Kontrolü
- `NSAppTransportSecurity` ayarları mevcut (development için)
- Production'da `NSAllowsArbitraryLoads: false` yapılmalı

### 3. App Store Connect Hazırlığı

#### 3.1 App Oluşturma
1. [App Store Connect](https://appstoreconnect.apple.com) → My Apps → +
2. **App Information**:
   - Name: TX Asistan
   - Primary Language: Turkish
   - Bundle ID: `com.turhibun.txManagerMobile` (önce oluşturulmalı)
   - SKU: `tx-asistan-001` (benzersiz bir değer)

#### 3.2 App Metadata
- **Description**: Uygulama açıklaması
- **Keywords**: İlgili anahtar kelimeler
- **Support URL**: Destek sayfası URL'i
- **Marketing URL** (opsiyonel)
- **Privacy Policy URL**: Gizlilik politikası URL'i (zorunlu)

#### 3.3 Screenshot ve Görseller
- **App Icon**: 1024x1024 PNG (zaten var: `Icon-App-1024x1024@1x.png`)
- **Screenshots**: 
  - iPhone 6.7" (1290 x 2796)
  - iPhone 6.5" (1284 x 2778)
  - iPhone 5.5" (1242 x 2208)
  - iPad Pro 12.9" (2048 x 2732)

### 4. Build ve Upload

#### 4.1 Release Build Oluşturma
```bash
cd mobile

# Clean build
flutter clean
flutter pub get

# iOS build
flutter build ipa --release
```

#### 4.2 Xcode ile Upload
1. Xcode → Window → Organizer
2. Archives sekmesinde build'i seç
3. **Distribute App** → **App Store Connect** → **Upload**
4. Signing seçeneklerini onayla
5. Upload'u tamamla

#### 4.3 Transporter ile Upload (Alternatif)
1. [Transporter](https://apps.apple.com/app/transporter/id1450874784) uygulamasını indir
2. `.ipa` dosyasını sürükle-bırak
3. Upload'u başlat

### 5. App Store Connect'te Yayınlama

1. **App Store Connect** → **My Apps** → **TX Asistan**
2. **+ Version** → Yeni versiyon oluştur (1.0.0)
3. **Build** seç → Upload edilen build'i seç
4. **What's New in This Version**: Versiyon notları
5. **App Review Information**:
   - Contact Information
   - Demo Account (gerekirse)
   - Notes (gerekirse)
6. **Version Release**: Otomatik veya manuel
7. **Submit for Review** → Onayla

---

## 🤖 Google Play Store Yükleme Adımları

### 1. Ön Hazırlık

#### 1.1 Google Play Console Hesabı
- [Google Play Console](https://play.google.com/console) hesabı ($25 tek seferlik ücret)
- Developer hesabı oluşturulmalı

#### 1.2 Android Studio ve SDK
- Android Studio yüklü olmalı
- Android SDK yüklü olmalı
- Java JDK 17 yüklü olmalı

### 2. Signing Key Oluşturma

#### 2.1 Keystore Oluşturma
```bash
cd mobile/android

# Keystore oluştur (İLK KEZ)
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Şifre ve bilgileri kaydedin!
```

#### 2.2 Key Properties Dosyası Oluşturma
`android/key.properties` dosyası oluşturun (`.gitignore`'a ekleyin!):
```properties
storePassword=<keystore-şifresi>
keyPassword=<key-şifresi>
keyAlias=upload
storeFile=<keystore-dosya-yolu>
```

#### 2.3 build.gradle.kts Güncelleme
`android/app/build.gradle.kts` dosyasını güncelleyin (signing config ekleyin)

### 3. Google Play Console Hazırlığı

#### 3.1 App Oluşturma
1. [Google Play Console](https://play.google.com/console) → Create app
2. **App name**: TX Asistan
3. **Default language**: Turkish (tr)
4. **App or game**: App
5. **Free or paid**: Free
6. **Declarations**: Gerekli beyanları yap

#### 3.2 App Content
- **Privacy Policy**: Gizlilik politikası URL'i (zorunlu)
- **Content rating**: İçerik derecelendirmesi
- **Target audience**: Hedef kitle
- **Data safety**: Veri güvenliği formu

### 4. Build ve Upload

#### 4.1 Release Build Oluşturma
```bash
cd mobile

# Clean build
flutter clean
flutter pub get

# Android App Bundle oluştur (önerilen)
flutter build appbundle --release

# Veya APK oluştur
flutter build apk --release
```

#### 4.2 Google Play Console'a Upload
1. **Google Play Console** → **TX Asistan** → **Production** (veya **Internal testing**)
2. **Create new release**
3. **App bundles and APKs** → **Upload** → `.aab` dosyasını seç
4. **Release name**: 1.0.0 (veya versiyon numarası)
5. **Release notes**: Versiyon notları
6. **Review release** → **Start rollout to Production**

### 5. Store Listing

#### 5.1 Store Listing Bilgileri
- **App name**: TX Asistan
- **Short description**: Kısa açıklama (80 karakter)
- **Full description**: Tam açıklama (4000 karakter)
- **App icon**: 512x512 PNG
- **Feature graphic**: 1024x500 PNG
- **Screenshots**: 
  - Phone: En az 2, en fazla 8 (16:9 veya 9:16)
  - Tablet (opsiyonel)
- **Category**: Uygun kategori seç

#### 5.2 Gerekli Görseller
- **App Icon**: 512x512 PNG (transparent background)
- **Feature Graphic**: 1024x500 PNG
- **Phone Screenshots**: Minimum 2 adet
- **Promo Graphic** (opsiyonel): 180x120 PNG

---

## 🔐 Güvenlik ve Gizlilik

### iOS
- Info.plist'te `NSAppTransportSecurity` production'da düzeltilmeli
- Privacy Policy URL'i App Store Connect'te eklenmeli

### Android
- `key.properties` dosyası `.gitignore`'a eklenmeli
- Keystore dosyası güvenli bir yerde saklanmalı
- Privacy Policy URL'i Google Play Console'da eklenmeli

---

## 📝 Checklist

### iOS App Store
- [ ] Apple Developer hesabı aktif
- [ ] Bundle ID App Store Connect'te oluşturuldu
- [ ] Xcode'da signing yapılandırıldı
- [ ] App icon (1024x1024) hazır
- [ ] Screenshots hazırlandı
- [ ] Privacy Policy URL hazır
- [ ] Release build oluşturuldu
- [ ] Build upload edildi
- [ ] App Store Connect'te metadata tamamlandı
- [ ] Review için submit edildi

### Google Play Store
- [ ] Google Play Developer hesabı oluşturuldu
- [ ] Keystore oluşturuldu ve güvenli saklandı
- [ ] `key.properties` dosyası oluşturuldu
- [ ] `build.gradle.kts` signing config eklendi
- [ ] App icon (512x512) hazır
- [ ] Feature graphic (1024x500) hazır
- [ ] Screenshots hazırlandı
- [ ] Privacy Policy URL hazır
- [ ] Release build (AAB) oluşturuldu
- [ ] Google Play Console'da app oluşturuldu
- [ ] Store listing tamamlandı
- [ ] Release upload edildi ve yayınlandı

---

## 🚀 Hızlı Başlangıç Komutları

### iOS
```bash
cd mobile
flutter clean
flutter pub get
flutter build ipa --release
# Sonra Xcode Organizer ile upload
```

### Android
```bash
cd mobile
flutter clean
flutter pub get
flutter build appbundle --release
# Sonra Google Play Console'a upload
```

---

## 📞 Destek

Sorun yaşarsanız:
- [Flutter Deployment Docs](https://docs.flutter.dev/deployment)
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
