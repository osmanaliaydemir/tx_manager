import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';

class ScheduledPostsScreen extends ConsumerStatefulWidget {
  const ScheduledPostsScreen({super.key});

  @override
  ConsumerState<ScheduledPostsScreen> createState() =>
      _ScheduledPostsScreenState();
}

class _ScheduledPostsScreenState extends ConsumerState<ScheduledPostsScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // PostStatus: 0=Draft, 1=Scheduled, 2=Published, 3=Failed
    final data = await ref.read(postRepositoryProvider).getPosts(status: '1');

    // Also fetch Published for history? Or separate tab.
    // Let's stick to Scheduled (1) and Published (2)
    // Actually API status should be int if c# enum.

    if (mounted) {
      setState(() {
        _posts = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Zamanlananlar"),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final post = _posts[index];
                return _buildPostCard(post);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "Zamanlanmış gönderi yok.",
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
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatter.format(date),
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "BEKLIYOR",
                  style: TextStyle(color: Colors.orange, fontSize: 10),
                ),
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
        ],
      ),
    );
  }
}
