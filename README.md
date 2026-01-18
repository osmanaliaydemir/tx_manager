# TX_Manager

## Overview
TX_Manager is a Clean Architecture .NET 9 Web API for scheduling and managing posts on X (Twitter).
It includes OAuth 2.0 PKCE authentication, post scheduling with Hangfire, and analytics placeholders.

## Prerequisites
- .NET 9 SDK
- SQL Server (LocalDB or Docker)

## Getting Started

1.  **Configure Database**
    Update `src/TX_Manager.Api/appsettings.json` with your SQL Server connection string.

2.  **Apply Migrations**
    ```bash
    dotnet ef database update -s src/TX_Manager.Api -p src/TX_Manager.Infrastructure
    ```

3.  **Run the API**
    ```bash
    dotnet run --project src/TX_Manager.Api
    ```

4.  **Access Swagger/Hangfire**
    - Swagger: `https://localhost:7198/swagger` (port may vary)
    - Hangfire: `https://localhost:7198/hangfire`

## Architecture
- **Domain**: Core entities and business rules (No dependencies).
- **Application**: Business logic, DTOs, Interfaces (Depends on Domain).
- **Infrastructure**: Persistence, External Services (Depends on Application & Domain).
- **Api**: Entry point, Controllers (Depends on Application & Infrastructure).

## Features
- **Auth**: Mock X API OAuth flow (see `AuthController`).
- **Scheduling**: Posts can be scheduled. A background job checks every minute for due posts.
- **Security**: Access tokens are encrypted using DPAPI (Windows) or AES (Failover/Linux).

## JWT Auth
- API artık mobil istemci için **JWT Bearer** kullanır.
- JWT ayarları: `src/TX_Manager.Api/appsettings.json` içindeki `Jwt` bölümü.
- Prod için **SigningKey’i appsettings’e yazmayın**: environment/secrets kullanın.

## Push Notifications (FCM)
Bu repo’da push altyapısı var; ancak Firebase dosyaları projeye eklenmeden push çalışmaz.

### Backend
- **Device token register**
  - `POST /api/notifications/device-tokens/register` (JWT gerekli)
  - `POST /api/notifications/device-tokens/unregister` (JWT gerekli)
- **Config**: `src/TX_Manager.Api/appsettings.json` içindeki `Push:Fcm`
  - `Enabled`: `true/false`
  - `ServerKey`: (secret/env önerilir)

### Mobile (Flutter)
- Paketler: `firebase_core`, `firebase_messaging`
- Firebase dosyaları (senin Firebase projen tarafından üretilmeli):
  - Android: `mobile/android/app/google-services.json`
  - iOS: `mobile/ios/Runner/GoogleService-Info.plist`
- Not: Kod, Firebase init başarısız olursa (dosyalar yoksa) **crash etmez** ve push register’ı atlar.

### Test (minimum)
1) Mobilde login ol → `AuthWebView` sonrası register denenecek.  
2) Backend’de `DeviceTokens` tablosunda ilgili kullanıcı için kayıt oluşmalı.  
3) `Push:Fcm:Enabled=true` + `ServerKey` verdikten sonra publish/suggestions event’leri push tetikler.

## Notes
- `XApiService` is currently a stub. Implement the HTTP calls to X API in `src/TX_Manager.Infrastructure/Services/XApiService.cs`.
