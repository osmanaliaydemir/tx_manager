import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/domain/entities/user_profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

class UserRepository {
  final _storage = const FlutterSecureStorage();

  Future<UserProfile?> getMyProfile() async {
    try {
      final userId = await _storage.read(key: 'auth_token');
      if (userId == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/me/$userId'),
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

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }
}
