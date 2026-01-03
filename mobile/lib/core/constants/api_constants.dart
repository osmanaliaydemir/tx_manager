class ApiConstants {
  // Use 10.0.2.2 for Android Emulator to reach localhost
  // Use localhost for iOS Simulator
  // Or use your runasp.net URL if running on real device

  static const String baseUrl = 'https://txmanager-api.runasp.net'; // Prod
  // static const String baseUrl = 'http://localhost:5064'; // Local (iOS) - HTTP
  // static const String baseUrl = 'https://localhost:7208'; // Local (iOS) - HTTPS (Self-signed issues)
  // static const String baseUrl = 'https://localhost:7208'; // Local (iOS) - HTTPS (Self-signed issues)

  static const String loginUrl = '$baseUrl/api/auth/login';
  static const String callbackUrl = '$baseUrl/api/auth/callback';
}
