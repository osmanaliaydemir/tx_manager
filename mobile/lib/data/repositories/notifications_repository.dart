import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/core/network/api_dio.dart';

final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(),
);

class NotificationsRepository {
  final Dio _dio = createApiDio();

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    await _dio.post(
      '/api/notifications/device-tokens/register',
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
    await _dio.post(
      '/api/notifications/device-tokens/unregister',
      data: {'token': token},
    );
  }
}
