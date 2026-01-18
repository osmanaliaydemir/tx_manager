import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';

final scheduledPostsProvider =
    AsyncNotifierProvider<ScheduledPostsController, List<dynamic>>(
      ScheduledPostsController.new,
    );

class ScheduledPostsController extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    // Source of truth is the API/DB. We keep optimistic items only in-memory.
    final repo = ref.read(postRepositoryProvider);
    return await repo.getPosts(status: '1');
  }

  Future<void> refresh() async {
    final repo = ref.read(postRepositoryProvider);
    try {
      final posts = await repo.getPosts(status: '1');
      state = AsyncData(posts);
    } catch (_) {
      // Best-effort refresh: keep current state (local cache) on failures.
    }
  }

  List<dynamic>? _safeValue(AsyncValue<List<dynamic>> v) {
    return v.maybeWhen(data: (d) => d, orElse: () => null);
  }

  Future<String> optimisticAdd({
    required String content,
    required DateTime scheduledForLocal,
  }) async {
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final current = _safeValue(state) ?? [];
    final optimistic = <String, dynamic>{
      'id': id,
      'content': content,
      'scheduledFor': scheduledForLocal.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': '1',
      // Used by UI to show "queued" badge while offline/outbox flushes.
      'isQueued': true,
    };

    state = AsyncData([optimistic, ...current]);
    return id;
  }

  Future<void> removeOptimistic(String localId) async {
    final current = _safeValue(state) ?? [];
    state = AsyncData(
      current.where((p) => (p['id']?.toString() ?? '') != localId).toList(),
    );
  }
}
