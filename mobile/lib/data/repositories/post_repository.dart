import 'package:dio/dio.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/core/offline/queued_offline_exception.dart';

final postRepositoryProvider = Provider(
  (ref) =>
      PostRepository(NotificationService.I, ref.read(outboxProcessorProvider)),
);

class PostRepository {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notifications;
  final OutboxProcessor _outbox;

  PostRepository(this._notifications, this._outbox);

  String _newIdempotencyKey() {
    // Offline outbox geldiğinde bu key'i persist edip retry'larda aynı key'i kullanacağız.
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
    String? idempotencyKey,
    bool fromOutbox = false,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    try {
      final headers = await _authHeaders(extra: {'Idempotency-Key': key});
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/api/posts',
        options: Options(headers: headers),
        data: {
          'content': content,
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
    } on DioException {
      if (!fromOutbox) {
        await _outbox.enqueue(OutboxActionType.createPost, {
          'content': content,
          'scheduledForUtc': scheduledFor?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw const QueuedOfflineException(
          'İnternet yok gibi görünüyor. Tweet kuyruğa alındı; bağlantı gelince otomatik gönderilecek.',
        );
      }
      rethrow;
    }
  }

  Future<List<dynamic>> createThread({
    required List<String> contents,
    DateTime? scheduledFor,
    String? idempotencyKey,
    bool fromOutbox = false,
  }) async {
    if (contents.isEmpty) throw Exception('Thread contents cannot be empty');

    final key = idempotencyKey ?? _newIdempotencyKey();
    try {
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
    } on DioException {
      if (!fromOutbox) {
        await _outbox.enqueue(OutboxActionType.createThread, {
          'contents': contents,
          'scheduledForUtc': scheduledFor?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw const QueuedOfflineException(
          'İnternet yok gibi görünüyor. Thread kuyruğa alındı; bağlantı gelince otomatik gönderilecek.',
        );
      }
      rethrow;
    }
  }

  Future<void> updatePost(
    String id,
    String content,
    DateTime? scheduledFor, {
    String? idempotencyKey,
    bool fromOutbox = false,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    try {
      final headers = await _authHeaders(extra: {'Idempotency-Key': key});
      await _dio.put(
        '${ApiConstants.baseUrl}/api/posts/$id',
        options: Options(headers: headers),
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
    } on DioException {
      if (!fromOutbox) {
        await _outbox.enqueue(OutboxActionType.updatePost, {
          'id': id,
          'content': content,
          'scheduledForUtc': scheduledFor?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw const QueuedOfflineException(
          'İnternet yok gibi görünüyor. Güncelleme kuyruğa alındı; bağlantı gelince otomatik uygulanacak.',
        );
      }
      rethrow;
    }
  }

  Future<void> deletePost(
    String id, {
    String? idempotencyKey,
    bool fromOutbox = false,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    try {
      final headers = await _authHeaders(extra: {'Idempotency-Key': key});
      await _dio.delete(
        '${ApiConstants.baseUrl}/api/posts/$id',
        options: Options(headers: headers),
      );
      await _notifications.cancelReminder(id);
    } on DioException {
      if (!fromOutbox) {
        await _outbox.enqueue(OutboxActionType.deletePost, {
          'id': id,
        }, idempotencyKey: key);
        throw const QueuedOfflineException(
          'İnternet yok gibi görünüyor. Silme işlemi kuyruğa alındı; bağlantı gelince otomatik uygulanacak.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPostById(String id) async {
    final headers = await _authHeaders();
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/api/posts/$id',
      options: Options(headers: headers),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelSchedule(
    String id, {
    String? idempotencyKey,
    bool fromOutbox = false,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    try {
      final headers = await _authHeaders(extra: {'Idempotency-Key': key});
      await _dio.post(
        '${ApiConstants.baseUrl}/api/posts/$id/cancel',
        options: Options(headers: headers),
      );
      await _notifications.cancelReminder(id);
    } on DioException {
      if (!fromOutbox) {
        await _outbox.enqueue(OutboxActionType.cancelSchedule, {
          'id': id,
        }, idempotencyKey: key);
        throw const QueuedOfflineException(
          'İnternet yok gibi görünüyor. İptal işlemi kuyruğa alındı; bağlantı gelince otomatik uygulanacak.',
        );
      }
      rethrow;
    }
  }
}
