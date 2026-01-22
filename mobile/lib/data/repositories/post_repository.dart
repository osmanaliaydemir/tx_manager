import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/core/network/api_dio.dart';
import 'dart:math';

final postRepositoryProvider = Provider(
  (ref) => PostRepository(NotificationService.I),
);

class PostRepository {
  final Dio _dio = createApiDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notifications;

  PostRepository(this._notifications);

  String _newIdempotencyKey() {
    final rand = Random.secure();
    final a = DateTime.now().microsecondsSinceEpoch;
    final b = rand.nextInt(1 << 32);
    final c = rand.nextInt(1 << 32);
    return '$a-$b-$c';
  }

  Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return {'Authorization': 'Bearer $token', if (extra != null) ...extra};
  }

  Future<List<dynamic>> getPosts({String? status}) async {
    final headers = await _authHeaders();

    final response = await _dio.get(
      '${ApiConstants.baseUrl}/api/posts',
      options: Options(headers: headers),
      queryParameters: {if (status != null) 'status': status},
    );

    return response.data;
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    DateTime? scheduledFor,
  }) async {
    final headers = await _authHeaders();

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/api/posts',
      options: Options(headers: headers),
      data: {
        'content': content,
        if (scheduledFor != null)
          'scheduledFor': scheduledFor
              .toUtc()
              .copyWith(microsecond: 0, millisecond: 0)
              .toIso8601String(),
      },
    );

    final data = response.data as Map<String, dynamic>;
    final id = data['id']?.toString();

    if (id != null && id.isNotEmpty && scheduledFor != null) {
      await _notifications.cancelReminder(id);
      await _notifications.scheduleReminder(
        postId: id,
        scheduledForLocal: scheduledFor,
      );
    }
    return data;
  }

  Future<List<dynamic>> createThread({
    required List<String> contents,
    DateTime? scheduledFor,
  }) async {
    if (contents.isEmpty) throw Exception('Thread contents cannot be empty');

    final key = _newIdempotencyKey();
    final headers = await _authHeaders(extra: {'Idempotency-Key': key});

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/api/posts/thread',
      options: Options(headers: headers),
      data: {
        if (scheduledFor != null)
          'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        'contents': contents,
      },
    );

    final list = response.data as List<dynamic>;
    if (scheduledFor != null && list.isNotEmpty) {
      final first = list.first;
      if (first is Map) {
        final id = first['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await _notifications.cancelReminder(id);
          await _notifications.scheduleReminder(
            postId: id,
            scheduledForLocal: scheduledFor,
          );
        }
      }
    }
    return list;
  }

  Future<void> updatePost(
    String id,
    String content,
    DateTime? scheduledFor,
  ) async {
    final key = _newIdempotencyKey();
    final headers = await _authHeaders(extra: {'Idempotency-Key': key});

    await _dio.put(
      '${ApiConstants.baseUrl}/api/posts/$id',
      options: Options(headers: headers),
      data: {
        'content': content,
        'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
      },
    );

    await _notifications.cancelReminder(id);
    if (scheduledFor != null) {
      await _notifications.scheduleReminder(
        postId: id,
        scheduledForLocal: scheduledFor,
      );
    }
  }

  Future<void> deletePost(String id) async {
    final key = _newIdempotencyKey();
    final headers = await _authHeaders(extra: {'Idempotency-Key': key});

    await _dio.delete(
      '${ApiConstants.baseUrl}/api/posts/$id',
      options: Options(headers: headers),
    );
    await _notifications.cancelReminder(id);
  }

  Future<Map<String, dynamic>> getPostById(String id) async {
    final headers = await _authHeaders();
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/api/posts/$id',
      options: Options(headers: headers),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelSchedule(String id) async {
    final headers = await _authHeaders();

    await _dio.post(
      '${ApiConstants.baseUrl}/api/posts/$id/cancel',
      options: Options(headers: headers),
    );
    await _notifications.cancelReminder(id);
  }
}
