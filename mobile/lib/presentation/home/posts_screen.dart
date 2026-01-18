import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/core/notifications/notification_service.dart';
import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/core/offline/outbox_executor.dart';
import 'package:tx_manager_mobile/core/offline/queued_offline_exception.dart';
import 'package:tx_manager_mobile/data/local/notified_posts_storage.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';
import 'package:tx_manager_mobile/data/repositories/suggestion_repository.dart';
import 'package:tx_manager_mobile/presentation/home/scheduled_posts_controller.dart';
import 'dart:async';

final postsProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  status,
) async {
  return ref.read(postRepositoryProvider).getPosts(status: status);
});

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  final NotifiedPostsStorage _notified = NotifiedPostsStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoRefresh();

    // Notify on newly seen Published/Failed posts (persisted to avoid duplicates).
    ref.listen<AsyncValue<List<dynamic>>>(postsProvider('2'), (
      prev,
      next,
    ) async {
      await _notifyIfNew(next, type: 'published');
    });
    ref.listen<AsyncValue<List<dynamic>>>(postsProvider('3'), (
      prev,
      next,
    ) async {
      await _notifyIfNew(next, type: 'failed');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh(immediate: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _startAutoRefresh({bool immediate = false}) {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    if (immediate) {
      _refreshAllLists();
    }

    // Hangfire 1 dakikada bir çalışıyor; 20-30sn polling yeterli.
    _refreshTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _refreshAllLists();
    });
  }

  void _refreshAllLists() {
    // Flush offline actions first (best-effort), then refresh server truth.
    ref
        .read(outboxProcessorProvider)
        .flushBestEffort(
          execute: (action) async {
            final exec = OutboxExecutor(
              posts: ref.read(postRepositoryProvider),
              suggestions: ref.read(suggestionRepositoryProvider),
            );
            await exec.execute(action);
          },
        );

    ref.invalidate(scheduledPostsProvider); // Scheduled (cached/offline)
    ref.invalidate(postsProvider('2')); // Published
    ref.invalidate(postsProvider('3')); // Failed
  }

  Future<void> _notifyIfNew(
    AsyncValue<List<dynamic>> async, {
    required String type,
  }) async {
    final posts = async.maybeWhen(data: (v) => v, orElse: () => null);
    if (posts == null || posts.isEmpty) return;

    for (final p in posts) {
      if (p is! Map) continue;
      final post = Map<String, dynamic>.from(p);
      final id = post['id']?.toString();
      if (id == null || id.isEmpty) continue;

      final key = '$type:$id';
      if (await _notified.has(key)) continue;

      final content = (post['content'] ?? '').toString();
      if (type == 'published') {
        await NotificationService.I.notifyPublished(
          postId: id,
          content: content,
        );
      } else if (type == 'failed') {
        final failureCode = post['failureCode']?.toString();
        await NotificationService.I.notifyFailed(
          postId: id,
          content: content,
          failureCode: failureCode,
        );
      }

      await _notified.add(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Gönderiler"),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: _refreshAllLists,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Zamanlananlar"),
              Tab(text: "Yayınlananlar"),
              Tab(text: "Başarısız"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PostList(status: '1'), // Scheduled
            PostList(status: '2'), // Published
            PostList(status: '3'), // Failed
          ],
        ),
      ),
    );
  }
}

class PostList extends ConsumerWidget {
  final String status;
  const PostList({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = status == '1'
        ? ref.watch(scheduledPostsProvider)
        : ref.watch(postsProvider(status));

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (posts) {
        if (posts.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            if (status == '1') {
              ref.invalidate(scheduledPostsProvider);
            } else {
              ref.invalidate(postsProvider(status));
            }
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(post: post, status: status);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_clear,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "Gönderi bulunamadı.",
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class PostCard extends ConsumerStatefulWidget {
  final dynamic post;
  final String status;

  const PostCard({super.key, required this.post, required this.status});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  Future<void> _retryNow(dynamic post) async {
    try {
      final now = DateTime.now();
      final scheduledFor = now.add(const Duration(minutes: 2));
      await ref
          .read(postRepositoryProvider)
          .updatePost(post['id'], post['content'] ?? '', scheduledFor);

      ref.invalidate(postsProvider('1'));
      ref.invalidate(postsProvider('2'));
      ref.invalidate(postsProvider('3'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yeniden deneme planlandı (2 dk sonra).'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is QueuedOfflineException ? e.message : 'Retry başarısız: $e',
            ),
            backgroundColor: e is QueuedOfflineException
                ? Colors.orange
                : Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final id = post['id']?.toString() ?? '';
    final content = post['content'] ?? '';
    final dateStr = post['scheduledFor'] ?? post['createdAt'];
    final date = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
    final formatter = DateFormat('dd MMM HH:mm');
    final isPublished = widget.status == '2';
    final isFailed = widget.status == '3';
    final isQueued = (post['isQueued'] == true) || id.startsWith('local-');
    final failureReason = post['failureReason']?.toString();
    final failureCode = post['failureCode']?.toString();

    // Analytics
    final likes = post['likeCount'] ?? 0;
    final retweets = post['retweetCount'] ?? 0;
    final views = post['impressionCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isPublished
                        ? Icons.check_circle
                        : isFailed
                        ? Icons.error
                        : Icons.schedule,
                    size: 16,
                    color: isPublished
                        ? Colors.green
                        : isFailed
                        ? Colors.redAccent
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatter.format(date),
                    style: TextStyle(
                      color: isPublished
                          ? Colors.green
                          : isFailed
                          ? Colors.redAccent
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isPublished
                                  ? Colors.green
                                  : isFailed
                                  ? Colors.redAccent
                                  : Colors.orange)
                              .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPublished
                          ? "YAYINLANDI"
                          : isFailed
                          ? "BAŞARISIZ"
                          : "BEKLIYOR",
                      style: TextStyle(
                        color: isPublished
                            ? Colors.green
                            : isFailed
                            ? Colors.redAccent
                            : Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (isQueued) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        "KUYRUKTA",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (!isPublished) ...[
                    if (isFailed) ...[
                      InkWell(
                        onTap: () => _retryNow(post),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh,
                            size: 18,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _showEditDialog(post),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showDeleteDialog(post),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          if (isFailed &&
              ((failureCode != null && failureCode.isNotEmpty) ||
                  (failureReason != null && failureReason.isNotEmpty))) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (failureCode != null && failureCode.isNotEmpty)
                          failureCode,
                        if (failureReason != null && failureReason.isNotEmpty)
                          failureReason,
                      ].join(': '),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPublished) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(Icons.visibility, views.toString()),
                  _buildStat(Icons.favorite, likes.toString()),
                  _buildStat(Icons.repeat, retweets.toString()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Future<void> _showDeleteDialog(dynamic post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252A34),
        title: const Text(
          "Gönderiyi Sil",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Bu gönderiyi silmek istediğinize emin misiniz?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(postRepositoryProvider).deletePost(post['id']);
      if (mounted) {
        // Refresh the list
        ref.invalidate(postsProvider(widget.status));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gönderi silindi"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(dynamic post) async {
    final contentController = TextEditingController(text: post['content']);
    DateTime scheduledDate =
        DateTime.tryParse(post['scheduledFor'] ?? '')?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    TimeOfDay scheduledTime = TimeOfDay.fromDateTime(scheduledDate);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final dateStr = DateFormat('dd MMM yyyy').format(scheduledDate);
          final timeStr = scheduledTime.format(dialogContext);

          return AlertDialog(
            backgroundColor: const Color(0xFF252A34),
            title: const Text(
              "Gönderiyi Düzenle",
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Tarih",
                      style: TextStyle(color: Colors.grey),
                    ),
                    subtitle: Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.calendar_today,
                      color: AppTheme.primaryColor,
                    ),
                    onTap: () async {
                      final dt = await showDatePicker(
                        context: dialogContext,
                        initialDate: scheduledDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (dt != null) setState(() => scheduledDate = dt);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Saat",
                      style: TextStyle(color: Colors.grey),
                    ),
                    subtitle: Text(
                      timeStr,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.access_time,
                      color: AppTheme.primaryColor,
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: dialogContext,
                        initialTime: scheduledTime,
                      );
                      if (t != null) setState(() => scheduledTime = t);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                onPressed: () async {
                  final newDateTime = DateTime(
                    scheduledDate.year,
                    scheduledDate.month,
                    scheduledDate.day,
                    scheduledTime.hour,
                    scheduledTime.minute,
                  );
                  await ref
                      .read(postRepositoryProvider)
                      .updatePost(
                        post['id'],
                        contentController.text,
                        newDateTime,
                      );

                  // Check specifically if the dialog context is still valid
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  // Check if the screen is still mounted to refresh data
                  if (mounted) {
                    // Refresh the list
                    ref.invalidate(postsProvider(widget.status));

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Gönderi güncellendi"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text(
                  "Kaydet",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
