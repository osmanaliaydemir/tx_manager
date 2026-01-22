import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/domain/entities/user_profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/notifications/push_registration_service.dart';
import 'package:tx_manager_mobile/core/network/api_dio.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

class AuthStatus {
  final bool hasToken;
  final DateTime? expiresAtUtc;
  final bool isExpired;
  final bool canRefresh;
  final bool requiresLogin;

  AuthStatus({
    required this.hasToken,
    required this.expiresAtUtc,
    required this.isExpired,
    required this.canRefresh,
    required this.requiresLogin,
  });

  factory AuthStatus.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expiresAtUtc']?.toString();
    return AuthStatus(
      hasToken: json['hasToken'] == true,
      expiresAtUtc: expiresAt != null ? DateTime.tryParse(expiresAt) : null,
      isExpired: json['isExpired'] == true,
      canRefresh: json['canRefresh'] == true,
      requiresLogin: json['requiresLogin'] == true,
    );
  }
}

class UserRepository {
  final _storage = const FlutterSecureStorage();
  final Dio _dio = createApiDio();

  Future<UserProfile?> getMyProfile() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return null;

      final res = await _dio.get('/api/auth/me');
      return UserProfile.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      return null;
    }
  }

  Future<AuthStatus?> getAuthStatus() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return null;

      final res = await _dio.get('/api/auth/status');
      return AuthStatus.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      debugPrint("Error fetching auth status: $e");
      return null;
    }
  }

  Future<void> updateTimezone({
    required String timeZoneName,
    required int timeZoneOffsetMinutes,
  }) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return;

      await _dio.post(
        '/api/auth/timezone',
        data: {
          'timeZoneName': timeZoneName,
          'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
        },
      );
    } catch (e) {
      debugPrint("Error updating timezone: $e");
    }
  }

  Future<void> logout() async {
    // Best-effort: unregister push token while JWT is still present.
    try {
      await PushRegistrationService.I.unregisterBestEffort();
    } catch (_) {
      // ignore
    }
    await _storage.delete(key: 'auth_token');
  }
}
