import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';
import 'package:tx_manager_mobile/data/repositories/suggestion_repository.dart';

class OutboxExecutor {
  final PostRepository posts;
  final SuggestionRepository suggestions;

  OutboxExecutor({required this.posts, required this.suggestions});

  String _key(OutboxAction a) {
    final k = a.payload['idempotencyKey']?.toString();
    return (k == null || k.trim().isEmpty) ? a.idempotencyKey : k.trim();
  }

  Future<void> execute(OutboxAction action) async {
    final key = _key(action);

    switch (action.type) {
      case OutboxActionType.createPost:
        await posts.createPost(
          content: (action.payload['content'] ?? '').toString(),
          scheduledFor: DateTime.tryParse(
            (action.payload['scheduledForUtc'] ?? '').toString(),
          )?.toLocal(),
          idempotencyKey: key,
          fromOutbox: true,
        );
        return;
      case OutboxActionType.createThread:
        final raw = action.payload['contents'];
        final contents = (raw is List)
            ? raw.map((e) => e.toString()).toList()
            : const <String>[];
        await posts.createThread(
          contents: contents,
          scheduledFor: DateTime.tryParse(
            (action.payload['scheduledForUtc'] ?? '').toString(),
          )?.toLocal(),
          idempotencyKey: key,
          fromOutbox: true,
        );
        return;
      case OutboxActionType.updatePost:
        await posts.updatePost(
          (action.payload['id'] ?? '').toString(),
          (action.payload['content'] ?? '').toString(),
          DateTime.tryParse(
            (action.payload['scheduledForUtc'] ?? '').toString(),
          )?.toLocal(),
          idempotencyKey: key,
          fromOutbox: true,
        );
        return;
      case OutboxActionType.deletePost:
        await posts.deletePost(
          (action.payload['id'] ?? '').toString(),
          idempotencyKey: key,
          fromOutbox: true,
        );
        return;
      case OutboxActionType.cancelSchedule:
        await posts.cancelSchedule(
          (action.payload['id'] ?? '').toString(),
          idempotencyKey: key,
          fromOutbox: true,
        );
        return;
      case OutboxActionType.acceptSuggestion:
        await suggestions.acceptSuggestion(
          (action.payload['suggestionId'] ?? '').toString(),
          auto: (action.payload['auto'] as bool?) ?? true,
          excludeWeekends:
              (action.payload['excludeWeekends'] as bool?) ?? false,
          preferredStartLocalHour:
              action.payload['preferredStartLocalHour'] as int?,
          preferredEndLocalHour:
              action.payload['preferredEndLocalHour'] as int?,
          scheduledForLocal: DateTime.tryParse(
            (action.payload['scheduledForUtc'] ?? '').toString(),
          )?.toLocal(),
          idempotencyKey: key,
          fromOutbox: true,
        );
        return;
      case OutboxActionType.rejectSuggestion:
        await suggestions.rejectSuggestion(
          (action.payload['suggestionId'] ?? '').toString(),
          reason: (action.payload['reason'] ?? '').toString(),
          idempotencyKey: key,
          fromOutbox: true,
        );
        return;
    }
  }
}
