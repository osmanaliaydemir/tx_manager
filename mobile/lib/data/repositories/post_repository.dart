import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/data/local/scheduled_posts_storage.dart';
import 'package:tx_manager_mobile/data/models/scheduled_post_model.dart';

final postRepositoryProvider = Provider(
  (ref) => PostRepository(NotificationService.I),
);

class PostRepository {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ScheduledPostsStorage _localStorage = ScheduledPostsStorage();
  final NotificationService _notifications;

  PostRepository(this._notifications);

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

      // Eğer scheduled posts ise (status == '1'), local'e kaydet
      if (status == '1' || status == null) {
        final List<dynamic> posts = response.data;
        final scheduledPosts = posts
            .where((p) {
              final s = (p['status']?.toString() ?? '').toLowerCase();
              return s == '1' || s == 'scheduled';
            })
            .map((p) => ScheduledPostModel.fromJson(p as Map<String, dynamic>))
            .toList();
        await _localStorage.mergeRemote(scheduledPosts);
      }

      return response.data;
    } catch (e) {
      // API hatası durumunda, scheduled posts için local'den yükle
      if (status == '1') {
        final localPosts = await _localStorage.loadPosts();
        return localPosts.map((p) => p.toJson()).toList();
      }
      return [];
    }
  }

  Future<List<ScheduledPostModel>> getScheduledPostsFromLocal() async {
    return await _localStorage.loadPosts();
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    DateTime? scheduledFor,
  }) async {
    final userId = await _storage.read(key: 'auth_token');
    if (userId == null) throw Exception('User not authenticated');

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/api/posts',
      data: {
        'content': content,
        'userId': userId,
        // Backend DateTime.UtcNow ile kıyaslıyor; UTC göndermezsek saat dilimi kayar.
        if (scheduledFor != null)
          'scheduledFor': scheduledFor.toUtc().toIso8601String(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    final id = data['id']?.toString();
    // Schedule local reminder (5 min before) for scheduled posts.
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
    final userId = await _storage.read(key: 'auth_token');
    if (userId == null) throw Exception('User not authenticated');
    if (contents.isEmpty) throw Exception('Thread contents cannot be empty');

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/api/posts/thread',
      data: {
        'userId': userId,
        if (scheduledFor != null)
          'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        'contents': contents,
      },
    );

    final list = response.data as List<dynamic>;
    // Use first post id as representative for reminder scheduling.
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
    await _dio.put(
      '${ApiConstants.baseUrl}/api/posts/$id',
      data: {
        'content': content,
        // Backend DateTime.UtcNow ile kıyaslıyor; UTC göndermezsek saat dilimi kayar.
        'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
      },
    );

    // Update reminder
    await _notifications.cancelReminder(id);
    if (scheduledFor != null) {
      await _notifications.scheduleReminder(
        postId: id,
        scheduledForLocal: scheduledFor,
      );
    }
  }

  Future<void> deletePost(String id) async {
    await _dio.delete('${ApiConstants.baseUrl}/api/posts/$id');
    await _notifications.cancelReminder(id);
  }

  Future<Map<String, dynamic>> getPostById(String id) async {
    final response = await _dio.get('${ApiConstants.baseUrl}/api/posts/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelSchedule(String id) async {
    await _dio.post('${ApiConstants.baseUrl}/api/posts/$id/cancel');
    await _notifications.cancelReminder(id);
  }
}
