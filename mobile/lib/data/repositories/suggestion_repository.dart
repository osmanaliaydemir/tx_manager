import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/domain/entities/content_suggestion.dart';

final suggestionRepositoryProvider = Provider((ref) => SuggestionRepository());

class SuggestionRepository {
  final Dio _dio =
      Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        )
        ..interceptors.add(
          LogInterceptor(
            request: true,
            requestHeader: true,
            requestBody: true,
            responseHeader: true,
            responseBody: true,
            error: true,
          ),
        );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> triggerGeneration() async {
    final userId = await _storage.read(key: 'auth_token');
    if (userId == null) return;

    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/api/suggestion/generate/$userId',
      );
    } catch (e) {
      throw Exception("Failed to trigger generation: $e");
    }
  }

  Future<List<ContentSuggestion>> getSuggestions() async {
    final userId = await _storage.read(key: 'auth_token');
    if (userId == null) return [];

    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/api/suggestion/$userId',
      );
      final List data = response.data;
      return data.map((json) => ContentSuggestion.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> acceptSuggestion(String suggestionId) async {
    await _dio.post(
      '${ApiConstants.baseUrl}/api/suggestion/$suggestionId/accept',
    );
  }

  Future<void> rejectSuggestion(String suggestionId) async {
    await _dio.post(
      '${ApiConstants.baseUrl}/api/suggestion/$suggestionId/reject',
    );
  }
}
