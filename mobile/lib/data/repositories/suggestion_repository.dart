import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/core/offline/queued_offline_exception.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/domain/entities/content_suggestion.dart';

final suggestionRepositoryProvider = Provider(
  (ref) => SuggestionRepository(ref.read(outboxProcessorProvider)),
);

class SuggestionRepository {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
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
    } on DioException {
      if (!fromOutbox) {
        await _outbox.enqueue(OutboxActionType.acceptSuggestion, {
          'suggestionId': suggestionId,
          'auto': auto,
          'excludeWeekends': excludeWeekends,
          'preferredStartLocalHour': preferredStartLocalHour,
          'preferredEndLocalHour': preferredEndLocalHour,
          'scheduledForUtc': scheduledForLocal?.toUtc().toIso8601String(),
        }, idempotencyKey: key);
        throw const QueuedOfflineException(
          'İnternet yok gibi görünüyor. Öneri aksiyonu kuyruğa alındı; bağlantı gelince otomatik uygulanacak.',
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
    } on DioException {
      if (!fromOutbox) {
        await _outbox.enqueue(OutboxActionType.rejectSuggestion, {
          'suggestionId': suggestionId,
          'reason': reason,
        }, idempotencyKey: key);
        throw const QueuedOfflineException(
          'İnternet yok gibi görünüyor. Reddetme işlemi kuyruğa alındı; bağlantı gelince otomatik uygulanacak.',
        );
      }
      rethrow;
    }
  }
}
