import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';

class ApprovalScreen extends ConsumerStatefulWidget {
  final String postId;
  const ApprovalScreen({super.key, required this.postId});

  @override
  ConsumerState<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends ConsumerState<ApprovalScreen> {
  bool _loading = true;
  Map<String, dynamic>? _post;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final post = await ref
          .read(postRepositoryProvider)
          .getPostById(widget.postId);
      setState(() => _post = post);
    } catch (e) {
      setState(() => _post = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _localScheduledFor() {
    final dt = DateTime.tryParse((_post?['scheduledFor'] ?? '').toString());
    return dt?.toLocal();
  }

  Future<void> _postpone(Duration d) async {
    final post = _post;
    if (post == null) return;
    final content = (post['content'] ?? '').toString();
    final scheduled = _localScheduledFor();
    if (scheduled == null) return;

    final newTime = scheduled.add(d);
    await ref
        .read(postRepositoryProvider)
        .updatePost(widget.postId, content, newTime);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ertelendi: ${DateFormat('dd MMM HH:mm').format(newTime)}',
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252A34),
        title: const Text('İptal et', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu planlamayı iptal etmek istiyor musun? (Taslak olarak kalacak)',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'İptal et',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await ref.read(postRepositoryProvider).cancelSchedule(widget.postId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Planlama iptal edildi')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final scheduledLocal = _localScheduledFor();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Onay / Ertele'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (post == null
                ? Center(
                    child: Text(
                      'Gönderi bulunamadı.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (post['content'] ?? '').toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (scheduledLocal != null)
                                Text(
                                  'Planlı: ${DateFormat('dd MMM yyyy HH:mm').format(scheduledLocal)}',
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (scheduledLocal != null) ...[
                          ElevatedButton.icon(
                            onPressed: () =>
                                _postpone(const Duration(minutes: 15)),
                            icon: const Icon(Icons.schedule),
                            label: const Text('15 dk ertele'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _postpone(const Duration(hours: 1)),
                            icon: const Icon(Icons.schedule),
                            label: const Text('1 saat ertele'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                          onPressed: _cancel,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                          ),
                          label: const Text('Planlamayı iptal et'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(
                              color: Colors.redAccent.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
    );
  }
}
