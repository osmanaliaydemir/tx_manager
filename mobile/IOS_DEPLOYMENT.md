# 🍎 iOS App Store Deployment Rehberi

## 📋 Mevcut Durum

- ✅ Xcode yüklü (26.2)
- ✅ DEVELOPMENT_TEAM: N3F82P5ZFV (zaten ayarlı)
- ✅ Bundle ID: `com.turhibun.txManagerMobile`
- ✅ App Icon: 1024x1024 mevcut
- ✅ App Name: TX Asistan

## 🚀 Hızlı Başlangıç

### 1. Xcode'da Projeyi Açma

```bash
cd /Users/osmanaliaydemir/Documents/TX_Manager/mobile
open ios/Runner.xcodeproj
```

### 2. Signing Kontrolü

Xcode'da:
1. **Runner** target'ını seçin (sol panel)
2. **Signing & Capabilities** sekmesine gidin
3. Kontrol edin:
   - ✅ **Automatically manage signing** işaretli
   - ✅ **Team**: Apple Developer hesabınız seçili
   - ✅ **Bundle Identifier**: `com.turhibun.txManagerMobile`
   - ✅ **Provisioning Profile**: Otomatik oluşturulacak

### 3. App Store Connect Hazırlığı

#### 3.1 App Store Connect'e Giriş
1. [App Store Connect](https://appstoreconnect.apple.com) → Giriş yapın
2. **My Apps** → **+** → **New App**

#### 3.2 App Bilgilerini Girin
- **Platform**: iOS
- **Name**: TX Asistan
- **Primary Language**: Turkish
- **Bundle ID**: `com.turhibun.txManagerMobile` (önce oluşturulmalı)
  - Eğer yoksa: **Certificates, Identifiers & Profiles** → **Identifiers** → **+** → **App IDs** → Oluştur
- **SKU**: `tx-asistan-001` (benzersiz bir değer)

### 4. Build Oluşturma

#### 4.1 Release Build (Önerilen: Xcode ile)
```bash
cd /Users/osmanaliaydemir/Documents/TX_Manager/mobile

# Clean ve dependencies
flutter clean
flutter pub get

# iOS dependencies
cd ios
pod install
cd ..
```

**Xcode'da:**
1. **Product** → **Scheme** → **Runner** seçili
2. **Product** → **Destination** → **Any iOS Device (arm64)**
3. **Product** → **Archive**
4. Archive tamamlandığında **Window** → **Organizer** açılacak

#### 4.2 Flutter CLI ile Build (Alternatif)
```bash
flutter build ipa --release
# Build: build/ios/ipa/tx_manager_mobile.ipa
```

### 5. Archive Upload

**Xcode Organizer'dan:**
1. **Archives** sekmesinde build'inizi seçin
2. **Distribute App** butonuna tıklayın
3. **App Store Connect** → **Next**
4. **Upload** → **Next**
5. **Automatically manage signing** → **Next**
6. **Upload** → İşlem tamamlanana kadar bekleyin

**Not:** Upload işlemi 10-30 dakika sürebilir. App Store Connect'te build'in görünmesi için biraz zaman gerekebilir.

### 6. App Store Connect'te Yayınlama

1. **App Store Connect** → **My Apps** → **TX Asistan**
2. **+ Version** veya **+ Platform** → **iOS**
3. **Build** seçin → Upload edilen build'i seçin
4. **Version Information**:
   - **What's New in This Version**: Versiyon notları
   - **Description**: Uygulama açıklaması (kısa)
   - **Keywords**: İlgili anahtar kelimeler (virgülle ayrılmış)
   - **Support URL**: Destek sayfası URL'i
   - **Marketing URL** (opsiyonel)
   - **Privacy Policy URL**: **ZORUNLU** - Gizlilik politikası URL'i

5. **App Review Information**:
   - **Contact Information**: İletişim bilgileri
   - **Demo Account** (gerekirse): Test hesabı bilgileri
   - **Notes**: Review ekibine notlar

6. **Version Release**:
   - **Manually release this version**: Manuel yayınlama
   - **Automatically release this version**: Otomatik yayınlama

7. **Submit for Review** → Onaylayın

## 📸 Gerekli Görseller

### App Icon
- ✅ **1024x1024 PNG** (Zaten var: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`)

### Screenshots
App Store Connect'te aşağıdaki boyutlarda screenshot'lar istenir:

#### iPhone (Zorunlu)
- **iPhone 6.7" Display**: 1290 x 2796 pixels (iPhone 14 Pro Max, 15 Pro Max)
- **iPhone 6.5" Display**: 1284 x 2778 pixels (iPhone 11 Pro Max, XS Max)
- **iPhone 5.5" Display**: 1242 x 2208 pixels (iPhone 8 Plus, 7 Plus, 6s Plus)

#### iPad (Opsiyonel ama önerilir)
- **iPad Pro 12.9"**: 2048 x 2732 pixels

**Not:** Screenshot'ları simülatörden veya gerçek cihazdan alabilirsiniz:
```bash
# Simülatörde app'i çalıştırıp screenshot al
flutter run -d "iPhone 15 Pro Max"
# Xcode → Device → Screenshots
```

## ⚠️ Önemli Notlar

### 1. NSAppTransportSecurity
Şu anda `Info.plist`'te `NSAllowsArbitraryLoads: true` var (development için). Production'da bu **false** yapılmalı veya özel domain exception'ları eklenmeli.

### 2. Privacy Policy
App Store Connect'te **Privacy Policy URL zorunlu**. Mutlaka ekleyin.

### 2.1 Privacy Manifest (iOS)
Apple’ın yeni gereksinimleri için `PrivacyInfo.xcprivacy` eklendi:
- `ios/Runner/PrivacyInfo.xcprivacy`

### 2.2 Repo içi Privacy Policy metni
Gizlilik politikası metni repo’ya eklendi:
- `PRIVACY_POLICY.md`
App Store Connect’e **URL** verilmesi gerektiği için bu dosyayı bir web sayfasına koyup (örn. GitHub Pages) URL’i kullanmalısın.

### 3. App Review Süresi
- İlk gönderim: Genellikle 1-3 gün
- Update: Genellikle 1-2 gün
- Rejection durumunda: Düzeltme sonrası tekrar gönderim

### 4. TestFlight (Beta Testing)
Production'a göndermeden önce TestFlight ile test edebilirsiniz:
1. Build'i upload edin
2. **TestFlight** sekmesinde build'i seçin
3. Internal/External test grupları oluşturun
4. Test edin

#### TestFlight – Pratik Akış (Hızlı)
1. `flutter build ipa --release`
2. `Transporter` ile `build/ios/ipa/*.ipa` upload
3. App Store Connect → TestFlight → Internal Testing → tester ekle
4. Crash-free hedefi: ilk gün **%99+** (backend: `/api/admin/jobs/publish/last`)

## 🔍 Checklist

- [ ] Apple Developer hesabı aktif
- [ ] App Store Connect'te app oluşturuldu
- [ ] Bundle ID App Store Connect'te kayıtlı
- [ ] Xcode'da signing yapılandırıldı
- [ ] Release build oluşturuldu (Archive)
- [ ] Build upload edildi
- [ ] App Store Connect'te build görünüyor
- [ ] App icon (1024x1024) hazır
- [ ] Screenshots hazırlandı (en az 3 boyut)
- [ ] Privacy Policy URL hazır
- [ ] Store listing metadata tamamlandı
- [ ] Review için submit edildi

## 🛠️ Sorun Giderme

### Archive oluşturamıyorum
- Xcode'da **Product** → **Clean Build Folder** (Cmd+Shift+K)
- `flutter clean` çalıştırın
- Pods'u yeniden yükleyin: `cd ios && pod install`

### Signing hatası
- Xcode'da **Signing & Capabilities** → **Team** seçili mi kontrol edin
- Apple Developer hesabınızda bundle ID kayıtlı mı kontrol edin

### Upload başarısız
- Internet bağlantınızı kontrol edin
- Xcode versiyonunuz güncel mi kontrol edin
- Transporter uygulamasını kullanabilirsiniz (alternatif)

### Build görünmüyor
- Upload işlemi 10-30 dakika sürebilir
- App Store Connect'te **Activity** sekmesini kontrol edin
- Bazen build'in işlenmesi zaman alabilir

## 📞 Yardım

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
