import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';

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

class PostList extends ConsumerStatefulWidget {
  final String status;
  const PostList({super.key, required this.status});

  @override
  ConsumerState<PostList> createState() => _PostListState();
}

class _PostListState extends ConsumerState<PostList> {
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await ref
        .read(postRepositoryProvider)
        .getPosts(status: widget.status);
    if (mounted) {
      setState(() {
        _posts = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_posts.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = _posts[index];
        return _buildPostCard(post);
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

  Widget _buildPostCard(dynamic post) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  if (!isPublished)
                    PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  onSelected: (value) => _handleMenuAction(value, post),
                  color: const Color(0xFF252A34),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Düzenle", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text("Sil", style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
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

  void _handleMenuAction(String value, dynamic post) {
    if (value == 'edit') {
      _showEditDialog(post);
    } else if (value == 'delete') {
      _showDeleteDialog(post);
    }
  }

  Future<void> _showDeleteDialog(dynamic post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252A34),
        title: const Text("Gönderiyi Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu gönderiyi silmek istediğinize emin misiniz?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sil", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(postRepositoryProvider).deletePost(post['id']);
      _loadData();
    }
  }

  Future<void> _showEditDialog(dynamic post) async {
    final contentController = TextEditingController(text: post['content']);
    DateTime scheduledDate = DateTime.tryParse(post['scheduledFor'] ?? '')?.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay scheduledTime = TimeOfDay.fromDateTime(scheduledDate);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final dateStr = DateFormat('dd MMM yyyy').format(scheduledDate);
          final timeStr = scheduledTime.format(context);

          return AlertDialog(
            backgroundColor: const Color(0xFF252A34),
            title: const Text("Gönderiyi Düzenle", style: TextStyle(color: Colors.white)),
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
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Tarih", style: TextStyle(color: Colors.grey)),
                    subtitle: Text(dateStr, style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                    onTap: () async {
                       final dt = await showDatePicker(
                           context: context,
                           initialDate: scheduledDate,
                           firstDate: DateTime.now(),
                           lastDate: DateTime.now().add(const Duration(days: 365)),
                       );
                       if (dt != null) setState(() => scheduledDate = dt);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Saat", style: TextStyle(color: Colors.grey)),
                    subtitle: Text(timeStr, style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.access_time, color: AppTheme.primaryColor),
                    onTap: () async {
                       final t = await showTimePicker(context: context, initialTime: scheduledTime);
                       if (t != null) setState(() => scheduledTime = t);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () async {
                   final newDateTime = DateTime(
                      scheduledDate.year, scheduledDate.month, scheduledDate.day,
                      scheduledTime.hour, scheduledTime.minute,
                   );
                   await ref.read(postRepositoryProvider).updatePost(
                      post['id'],
                      contentController.text,
                      newDateTime,
                   );
                   if (mounted) {
                     Navigator.pop(context);
                     _loadData();
                   }
                },
                child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
