import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';

final postRepositoryProvider = Provider((ref) => PostRepository());

class PostRepository {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<dynamic>> getPosts({String? status}) async {
    final userId = await _storage.read(key: 'auth_token');
    if (userId == null) return [];

    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/api/posts',
        queryParameters: {
          'userId': userId,
          if (status != null) 'status': status,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<void> updatePost(
    String id,
    String content,
    DateTime? scheduledFor,
  ) async {
    await _dio.put(
      '${ApiConstants.baseUrl}/api/posts/$id',
      data: {
        'content': content,
        'scheduledFor': scheduledFor?.toIso8601String(),
      },
    );
  }

  Future<void> deletePost(String id) async {
    await _dio.delete('${ApiConstants.baseUrl}/api/posts/$id');
  }
}
