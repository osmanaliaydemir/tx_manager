# tx_manager_mobile

A new Flutter project.

## Getting Started

This project is a Flutter client for TX_Manager.

## Push notifications (FCM)
Push entegrasyonu opsiyonel ve **best-effort** çalışır:
- Firebase dosyaları eklenmemişse uygulama crash etmez, token register adımı skip edilir.

### Firebase dosyaları (zorunlu)
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

### Paketler
- `firebase_core`
- `firebase_messaging`

### Akış
- Login sonrası (`AuthWebView`) FCM token backend’e register edilir.
- Logout sırasında token backend’den unregister edilir (best-effort).

## Dev links
- API base: `lib/core/constants/api_constants.dart`

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
