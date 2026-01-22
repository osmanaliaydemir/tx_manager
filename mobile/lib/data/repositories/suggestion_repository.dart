import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/core/offline/queued_offline_exception.dart';
import 'package:tx_manager_mobile/core/network/api_dio.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/domain/entities/content_suggestion.dart';

final suggestionRepositoryProvider = Provider(
  (ref) => SuggestionRepository(ref.read(outboxProcessorProvider)),
);

class SuggestionRepository {
  final Dio _dio = createApiDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final OutboxProcessor _outbox;

  SuggestionRepository(this._outbox);

  String _newIdempotencyKey() => _outbox.newIdempotencyKey();

  Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return {'Authorization': 'Bearer $token', if (extra != null) ...extra};
  }

  bool _shouldEnqueue(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) {
      if (status == 401 || status == 403) return false;
      if (status >= 400 && status < 500 && status != 409 && status != 429) {
        return false;
      }
      return status == 409 || status == 429 || status >= 500;
    }

    if (e.type == DioExceptionType.unknown) {
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

  Future<void> triggerGeneration() async {
    try {
      final headers = await _authHeaders();
      await _dio.post(
        '${ApiConstants.baseUrl}/api/suggestions/generate',
        options: Options(headers: headers),
      );
    } catch (e) {
      throw Exception("Failed to trigger generation: $e");
    }
  }

  Future<List<ContentSuggestion>> getSuggestions({
    String status = 'Pending',
    int take = 20,
    String? cursor,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/api/suggestions',
        options: Options(headers: headers),
        queryParameters: {
          'status': status,
          'take': take,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map(
            (json) =>
                ContentSuggestion.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> acceptSuggestion(
    String suggestionId, {
    DateTime? scheduledForLocal,
    bool auto = true,
    bool excludeWeekends = false,
    int? preferredStartLocalHour,
    int? preferredEndLocalHour,
    String? idempotencyKey,
    bool fromOutbox = false,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    try {
      final headers = await _authHeaders(extra: {'Idempotency-Key': key});
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/api/suggestions/$suggestionId/accept',
        options: Options(headers: headers),
        data: auto
            ? {
                'mode': 'Auto',
                'schedulePolicy': {
                  'excludeWeekends': excludeWeekends,
                  if (preferredStartLocalHour != null)
                    'preferredStartLocalHour': preferredStartLocalHour,
                  if (preferredEndLocalHour != null)
                    'preferredEndLocalHour': preferredEndLocalHour,
                },
              }
            : {
                'mode': 'Manual',
                'scheduledForUtc': scheduledForLocal?.toUtc().toIso8601String(),
              },
      );

      // Schedule local reminder using returned postId + scheduledForUtc
      try {
        final data = response.data as Map<String, dynamic>;
        final postId = data['postId']?.toString();
        final scheduledForUtc = DateTime.tryParse(
          (data['scheduledForUtc'] ?? '').toString(),
        );
        if (postId != null && postId.isNotEmpty && scheduledForUtc != null) {
          final local = scheduledForUtc.toLocal();
          await NotificationService.I.cancelReminder(postId);
          await NotificationService.I.scheduleReminder(
            postId: postId,
            scheduledForLocal: local,
          );
        }
      } catch (_) {
        // Best-effort: do not block UX if parsing/scheduling fails
      }
    } on DioException catch (dioException) {
      if (!fromOutbox && _shouldEnqueue(dioException)) {
        if (kDebugMode) {
          debugPrint(
            'enqueue:acceptSuggestion status=${dioException.response?.statusCode} '
            'type=${dioException.type} err=${dioException.error} '
            'data=${dioException.response?.data}',
          );
        }
        await _outbox.enqueue(OutboxActionType.acceptSuggestion, {
          'suggestionId': suggestionId,
          'auto': auto,
          'excludeWeekends': excludeWeekends,
          'preferredStartLocalHour': preferredStartLocalHour,
          'preferredEndLocalHour': preferredEndLocalHour,
          'scheduledForUtc': scheduledForLocal?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw QueuedOfflineException(
          _queuedMessage(dioException, 'acceptSuggestion'),
        );
      }
      rethrow;
    }
  }

  Future<void> rejectSuggestion(
    String suggestionId, {
    String? reason,
    String? idempotencyKey,
    bool fromOutbox = false,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    try {
      final headers = await _authHeaders(extra: {'Idempotency-Key': key});
      await _dio.post(
        '${ApiConstants.baseUrl}/api/suggestions/$suggestionId/reject',
        options: Options(headers: headers),
        data: reason == null || reason.trim().isEmpty
            ? {}
            : {'reason': reason.trim()},
      );
    } on DioException catch (dioException) {
      if (!fromOutbox && _shouldEnqueue(dioException)) {
        if (kDebugMode) {
          debugPrint(
            'enqueue:rejectSuggestion status=${dioException.response?.statusCode} '
            'type=${dioException.type} err=${dioException.error} '
            'data=${dioException.response?.data}',
          );
        }
        await _outbox.enqueue(OutboxActionType.rejectSuggestion, {
          'suggestionId': suggestionId,
          'reason': reason,
        }, idempotencyKey: key);
        throw QueuedOfflineException(
          _queuedMessage(dioException, 'rejectSuggestion'),
        );
      }
      rethrow;
    }
  }
}
