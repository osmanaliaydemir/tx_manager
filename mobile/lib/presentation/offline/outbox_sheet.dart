import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';

class OutboxSheet extends ConsumerWidget {
  final Future<void> Function() onFlushNow;
  final Future<void> Function(String actionId) onRetryOne;

  const OutboxSheet({
    super.key,
    required this.onFlushNow,
    required this.onRetryOne,
  });

  String _titleFor(OutboxActionType t) {
    switch (t) {
      case OutboxActionType.createPost:
        return 'Tweet oluştur';
      case OutboxActionType.createThread:
        return 'Thread oluştur';
      case OutboxActionType.updatePost:
        return 'Tweet güncelle';
      case OutboxActionType.deletePost:
        return 'Tweet sil';
      case OutboxActionType.cancelSchedule:
        return 'Planlama iptal';
      case OutboxActionType.acceptSuggestion:
        return 'Öneri kabul';
      case OutboxActionType.rejectSuggestion:
        return 'Öneri reddet';
    }
  }

  String _summary(OutboxAction a) {
    String clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

    switch (a.type) {
      case OutboxActionType.createPost:
        return clip((a.payload['content'] ?? '').toString(), 60);
      case OutboxActionType.createThread:
        final raw = a.payload['contents'];
        if (raw is List) return 'Parça: ${raw.length}';
        return 'Thread';
      case OutboxActionType.updatePost:
        return 'ID: ${(a.payload['id'] ?? '').toString()}';
      case OutboxActionType.deletePost:
        return 'ID: ${(a.payload['id'] ?? '').toString()}';
      case OutboxActionType.cancelSchedule:
        return 'ID: ${(a.payload['id'] ?? '').toString()}';
      case OutboxActionType.acceptSuggestion:
        return 'Suggestion: ${(a.payload['suggestionId'] ?? '').toString()}';
      case OutboxActionType.rejectSuggestion:
        return 'Suggestion: ${(a.payload['suggestionId'] ?? '').toString()}';
    }
  }

  String? _hintFor(OutboxAction a) {
    final err = a.lastError ?? '';
    if (err == 'HTTP 401' || err == 'HTTP 403') {
      return 'Giriş gerekli: X hesabına tekrar giriş yap.';
    }
    if (err == 'HTTP 429') {
      return 'Rate limit: biraz bekleyip tekrar dene.';
    }
    if (err.startsWith('HTTP 4')) {
      return 'İstek reddedildi: bu item muhtemelen geçersiz. Silip yeniden deneyebilirsin.';
    }
    if (a.isDeadLettered) {
      return 'Manuel müdahale gerekiyor: “Şimdi dene (bu)” ile tekrar deneyebilirsin.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(outboxItemsProvider);
    final fmt = DateFormat('dd MMM HH:mm');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF252A34),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: itemsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Hata: $e',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            data: (items) {
              final needsLogin = items.any(
                (a) => a.lastError == 'HTTP 401' || a.lastError == 'HTTP 403',
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Kuyruk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Yenile',
                        onPressed: () => ref.invalidate(outboxItemsProvider),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (needsLogin) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bazı işlemler giriş gerektiriyor (401/403).',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/auth_webview'),
                            child: const Text('Giriş Yap'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (items.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Kuyruk boş.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (context, i) {
                          final a = items[i];
                          final created = a.createdAtUtc.toLocal();
                          final next = a.nextAttemptAtUtc.toLocal();
                          final lastAttempt = a.lastAttemptAtUtc?.toLocal();
                          final isDead = a.isDeadLettered;
                          final hint = _hintFor(a);
                          final err = a.lastError ?? '';
                          final needsLoginForItem =
                              err == 'HTTP 401' || err == 'HTTP 403';
                          return ListTile(
                            title: Text(
                              _titleFor(a.type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${_summary(a)}\n'
                              'Oluşturma: ${fmt.format(created)} • Retry: ${a.retryCount} • Sonraki: ${fmt.format(next)}\n'
                              '${isDead ? 'Durum: MANUEL (dead-letter)' : 'Durum: Otomatik'}'
                              '${lastAttempt == null ? '' : ' • Son deneme: ${fmt.format(lastAttempt)}'}'
                              '${(a.lastError == null || a.lastError!.isEmpty) ? '' : ' • Hata: ${a.lastError}'}'
                              '${hint == null ? '' : '\n$hint'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12,
                              ),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              tooltip: 'İşlem',
                              color: const Color(0xFF252A34),
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white70,
                              ),
                              onSelected: (v) async {
                                if (v == 'retry') {
                                  await onRetryOne(a.id);
                                  if (context.mounted) {
                                    ref.invalidate(outboxItemsProvider);
                                  }
                                  return;
                                }
                                if (v == 'login') {
                                  if (context.mounted) {
                                    context.push('/auth_webview');
                                  }
                                  return;
                                }
                                if (v == 'copy') {
                                  final details =
                                      'type=${a.type.name}\n'
                                      'id=${a.id}\n'
                                      'idempotencyKey=${a.idempotencyKey}\n'
                                      'retryCount=${a.retryCount}\n'
                                      'nextAttemptAtUtc=${a.nextAttemptAtUtc.toIso8601String()}\n'
                                      'lastAttemptAtUtc=${a.lastAttemptAtUtc?.toIso8601String() ?? ''}\n'
                                      'lastError=${a.lastError ?? ''}\n'
                                      'payload=${a.payload}\n';
                                  await Clipboard.setData(
                                    ClipboardData(text: details),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Detaylar kopyalandı'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                if (v == 'delete') {
                                  await ref
                                      .read(outboxStoreProvider)
                                      .removeById(a.id);
                                  ref.invalidate(outboxItemsProvider);
                                  return;
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'retry',
                                  child: Text(
                                    'Şimdi dene (bu)',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (needsLoginForItem)
                                  const PopupMenuItem(
                                    value: 'login',
                                    child: Text(
                                      'Giriş yap',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'copy',
                                  child: Text(
                                    'Detayları kopyala',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Sil (bu)',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: items.isEmpty
                              ? null
                              : () async {
                                  await onFlushNow();
                                  if (context.mounted) {
                                    ref.invalidate(outboxItemsProvider);
                                  }
                                },
                          icon: const Icon(
                            Icons.cloud_upload,
                            color: Colors.white,
                          ),
                          label: const Text('Şimdi dene'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: items.isEmpty
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF252A34),
                                    title: const Text(
                                      'Kuyruğu temizle',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'Kuyruktaki tüm işlemler silinecek. Emin misin?',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Vazgeç'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Temizle',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(outboxStoreProvider).clear();
                                  ref.invalidate(outboxItemsProvider);
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text('Temizle'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
