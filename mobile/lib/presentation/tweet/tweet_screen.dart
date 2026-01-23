import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

final scheduledPostsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final repo = ref.read(postRepositoryProvider);
  // Backend'den 'scheduled' statüsündeki tweetleri çekiyoruz
  final list = await repo.getPosts(status: 'scheduled');

  // Tarihe göre sırala (Eskiden yeniye)
  list.sort((a, b) {
    final t1 = a['scheduledFor']?.toString();
    final t2 = b['scheduledFor']?.toString();
    if (t1 == null || t2 == null) return 0;
    return DateTime.parse(t1).compareTo(DateTime.parse(t2));
  });

  return list;
});

class TweetScreen extends ConsumerStatefulWidget {
  const TweetScreen({super.key});

  @override
  ConsumerState<TweetScreen> createState() => _TweetScreenState();
}

class _TweetScreenState extends ConsumerState<TweetScreen> {
  final _textController = TextEditingController();
  DateTime? _scheduledTime;
  bool _isSending = false;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
    );
    if (time == null) return;

    setState(() {
      _scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _sendTweet() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen içerik giriniz.')));
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref
          .read(postRepositoryProvider)
          .createPost(
            content: _textController.text,
            scheduledFor: _scheduledTime,
          );

      if (mounted) {
        final msg = _scheduledTime == null
            ? 'Tweet gönderildi!'
            : 'Tweet başarıyla zamanlandı.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));

        _textController.clear();
        setState(() => _scheduledTime = null);

        // Listeyi yenile
        ref.invalidate(scheduledPostsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _cancelSchedule(String id) async {
    try {
      await ref.read(postRepositoryProvider).cancelSchedule(id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Planlama iptal edildi.")));
      ref.invalidate(scheduledPostsProvider);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  Future<void> _logout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduledList = ref.watch(scheduledPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tweet Gönder'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                maxLines: 5,
                style: const TextStyle(fontSize: 16),
                enableInteractiveSelection: true,
                decoration: const InputDecoration(
                  hintText: 'Ne paylaşmak istersin?',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scheduledTime == null
                            ? 'Hemen gönder'
                            : 'Zamanlandı: ${DateFormat('dd MMM HH:mm').format(_scheduledTime!)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_scheduledTime != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _scheduledTime = null),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.calendar_month,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: _pickDateTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendTweet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _scheduledTime == null ? 'TWEET AT' : 'ZAMANLA',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Zamanlananlar",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: scheduledList.when(
                  data: (posts) {
                    if (posts.isEmpty) {
                      return const Center(
                        child: Text(
                          "Henüz planlanmış tweet yok.",
                          style: TextStyle(color: Colors.white38),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final content = post['content'] ?? '';
                        final dateStr = post['scheduledFor'];
                        final date = dateStr != null
                            ? DateTime.tryParse(dateStr)?.toLocal()
                            : null;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (date != null)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: AppTheme.primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat(
                                              'dd MMM yyyy, HH:mm',
                                            ).format(date),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () =>
                                    _cancelSchedule(post['id'].toString()),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  error: (e, s) => Center(
                    child: Text(
                      "Hata oluştu: $e",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
