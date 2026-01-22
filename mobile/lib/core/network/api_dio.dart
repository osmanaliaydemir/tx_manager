import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/auth/auth_required_coordinator.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';

Dio createApiDio({
  Duration connectTimeout = const Duration(seconds: 10),
  Duration receiveTimeout = const Duration(seconds: 15),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    ),
  );

  const storage = FlutterSecureStorage();

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // If caller already supplied Authorization, keep it.
        if (!options.headers.containsKey('Authorization')) {
          final token = await storage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          // Centralized auth-required UX.
          await AuthRequiredCoordinator.I.handle(statusCode: status);
        }
        handler.next(e);
      },
    ),
  );

  return dio;
}
