import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';

final postsProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  status,
) async {
  return ref.read(postRepositoryProvider).getPosts(status: status);
});

class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Gönderiler"),
          backgroundColor: Colors.transparent,
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Zamanlananlar"),
              Tab(text: "Yayınlananlar"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PostList(status: '1'), // Scheduled
            PostList(status: '2'), // Published
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
    final postsAsync = ref.watch(postsProvider(status));

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (posts) {
        if (posts.isEmpty) return _buildEmptyState();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post, status: status);
          },
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
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final content = post['content'] ?? '';
    final dateStr = post['scheduledFor'] ?? post['createdAt'];
    final date = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
    final formatter = DateFormat('dd MMM HH:mm');
    final isPublished = widget.status == '2';

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
                    isPublished ? Icons.check_circle : Icons.schedule,
                    size: 16,
                    color: isPublished ? Colors.green : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatter.format(date),
                    style: TextStyle(
                      color: isPublished ? Colors.green : AppTheme.primaryColor,
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
                      color: (isPublished ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPublished ? "YAYINLANDI" : "BEKLIYOR",
                      style: TextStyle(
                        color: isPublished ? Colors.green : Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (!isPublished) ...[
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
