import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';

final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(),
);

class NotificationsRepository {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    final headers = await _authHeaders();
    await _dio.post(
      '${ApiConstants.baseUrl}/api/notifications/device-tokens/register',
      options: Options(headers: headers),
      data: {
        'token': token,
        // Backend enum: Unknown/Android/Ios/Web
        'platform': platform,
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'deviceId': deviceId.trim(),
      },
    );
  }

  Future<void> unregisterDeviceToken({required String token}) async {
    final headers = await _authHeaders();
    await _dio.post(
      '${ApiConstants.baseUrl}/api/notifications/device-tokens/unregister',
      options: Options(headers: headers),
      data: {'token': token},
    );
  }
}
