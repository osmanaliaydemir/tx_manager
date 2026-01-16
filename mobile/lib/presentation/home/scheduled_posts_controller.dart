import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/data/local/scheduled_posts_storage.dart';
import 'package:tx_manager_mobile/data/models/scheduled_post_model.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';

final scheduledPostsProvider =
    AsyncNotifierProvider<ScheduledPostsController, List<dynamic>>(
      ScheduledPostsController.new,
    );

class ScheduledPostsController extends AsyncNotifier<List<dynamic>> {
  final ScheduledPostsStorage _storage = ScheduledPostsStorage();

  @override
  Future<List<dynamic>> build() async {
    // Load local cache immediately for offline/instant UX.
    final local = await _storage.loadPosts();

    // Best-effort refresh from API in background.
    Future.microtask(refresh);

    return local.map((p) => p.toJson()).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<dynamic>>().copyWithPrevious(state);
    final repo = ref.read(postRepositoryProvider);
    final posts = await repo.getPosts(status: '1');
    state = AsyncData(posts);
  }

  List<dynamic>? _safeValue(AsyncValue<List<dynamic>> v) {
    return v.maybeWhen(data: (d) => d, orElse: () => null);
  }

  Future<String> optimisticAdd({
    required String content,
    required DateTime scheduledForLocal,
  }) async {
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    await _storage.upsertLocal(
      id: id,
      content: content,
      scheduledForLocal: scheduledForLocal,
    );

    final current = _safeValue(state) ?? [];
    final optimistic = <String, dynamic>{
      'id': id,
      'content': content,
      'scheduledFor': scheduledForLocal.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': '1',
    };

    state = AsyncData([optimistic, ...current]);
    return id;
  }

  Future<void> removeOptimistic(String localId) async {
    await _storage.removeById(localId);
    final current = _safeValue(state) ?? [];
    state = AsyncData(
      current.where((p) => (p['id']?.toString() ?? '') != localId).toList(),
    );
  }
}
