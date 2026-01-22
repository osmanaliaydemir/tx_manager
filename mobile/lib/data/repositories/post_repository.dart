import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/core/offline/queued_offline_exception.dart';
import 'package:tx_manager_mobile/core/network/api_dio.dart';

final postRepositoryProvider = Provider(
  (ref) =>
      PostRepository(NotificationService.I, ref.read(outboxProcessorProvider)),
);

class PostRepository {
  final Dio _dio = createApiDio();
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

  bool _shouldEnqueue(DioException e) {
    // Only queue when it's likely a connectivity / transient infra issue.
    // If server responded with 4xx (auth/validation), do NOT queue.
    final status = e.response?.statusCode;
    if (status != null) {
      if (status == 401 || status == 403) return false; // login required
      if (status >= 400 && status < 500 && status != 409 && status != 429) {
        return false; // client error, won't succeed by retrying
      }
      // 409/429/5xx are potentially retryable
      return status == 409 || status == 429 || status >= 500;
    }

    // No response -> network-ish
    if (e.type == DioExceptionType.unknown) {
      // Unknown can be non-network (e.g. programmer error). Only treat as network
      // when underlying error is a socket/TLS/HTTP exception.
      final err = e.error;
      return err is SocketException ||
          err is HandshakeException ||
          err is HttpException;
    }
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  String _queuedMessage(DioException e, String op) {
    final status = e.response?.statusCode;
    if (status == 500 || status == 502 || status == 503 || status == 504) {
      return 'Sunucu hatası (HTTP $status). İşlem kuyruğa alındı; birazdan tekrar denenecek.';
    }
    if (status == 429) {
      return 'Çok fazla istek (rate limit). İşlem kuyruğa alındı; birazdan tekrar denenecek.';
    }
    if (status == 409) {
      return 'İşlem zaten devam ediyor (409). Kuyruğa alındı; tekrar denenecek.';
    }
    return 'Bağlantı sorunu nedeniyle gönderilemedi. İşlem kuyruğa alındı; bağlantı gelince otomatik denenecek.';
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
    } on DioException catch (dioException) {
      if (!fromOutbox && _shouldEnqueue(dioException)) {
        if (kDebugMode) {
          debugPrint(
            'enqueue:createPost status=${dioException.response?.statusCode} '
            'type=${dioException.type} err=${dioException.error} '
            'data=${dioException.response?.data}',
          );
        }
        await _outbox.enqueue(OutboxActionType.createPost, {
          'content': content,
          'scheduledForUtc': scheduledFor?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw QueuedOfflineException(
          _queuedMessage(dioException, 'createPost'),
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
    } on DioException catch (dioException) {
      if (!fromOutbox && _shouldEnqueue(dioException)) {
        if (kDebugMode) {
          debugPrint(
            'enqueue:createThread status=${dioException.response?.statusCode} '
            'type=${dioException.type} err=${dioException.error} '
            'data=${dioException.response?.data}',
          );
        }
        await _outbox.enqueue(OutboxActionType.createThread, {
          'contents': contents,
          'scheduledForUtc': scheduledFor?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw QueuedOfflineException(
          _queuedMessage(dioException, 'createThread'),
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
    } on DioException catch (dioException) {
      if (!fromOutbox && _shouldEnqueue(dioException)) {
        if (kDebugMode) {
          debugPrint(
            'enqueue:updatePost status=${dioException.response?.statusCode} '
            'type=${dioException.type} err=${dioException.error} '
            'data=${dioException.response?.data}',
          );
        }
        await _outbox.enqueue(OutboxActionType.updatePost, {
          'id': id,
          'content': content,
          'scheduledForUtc': scheduledFor?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw QueuedOfflineException(
          _queuedMessage(dioException, 'updatePost'),
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
    } on DioException catch (dioException) {
      if (!fromOutbox && _shouldEnqueue(dioException)) {
        if (kDebugMode) {
          debugPrint(
            'enqueue:deletePost status=${dioException.response?.statusCode} '
            'type=${dioException.type} err=${dioException.error} '
            'data=${dioException.response?.data}',
          );
        }
        await _outbox.enqueue(OutboxActionType.deletePost, {
          'id': id,
        }, idempotencyKey: key);
        throw QueuedOfflineException(
          _queuedMessage(dioException, 'deletePost'),
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
    } on DioException catch (dioException) {
      if (!fromOutbox && _shouldEnqueue(dioException)) {
        if (kDebugMode) {
          debugPrint(
            'enqueue:cancelSchedule status=${dioException.response?.statusCode} '
            'type=${dioException.type} err=${dioException.error} '
            'data=${dioException.response?.data}',
          );
        }
        await _outbox.enqueue(OutboxActionType.cancelSchedule, {
          'id': id,
        }, idempotencyKey: key);
        throw QueuedOfflineException(
          _queuedMessage(dioException, 'cancelSchedule'),
        );
      }
      rethrow;
    }
  }
}
