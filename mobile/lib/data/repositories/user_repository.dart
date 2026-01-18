import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/domain/entities/user_profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/notifications/push_registration_service.dart';

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

  Future<UserProfile?> getMyProfile() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return null;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      return null;
    }
  }

  Future<AuthStatus?> getAuthStatus() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return null;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/auth/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AuthStatus.fromJson(data);
      }
      return null;
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

      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/auth/timezone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'timeZoneName': timeZoneName,
          'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
        }),
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
