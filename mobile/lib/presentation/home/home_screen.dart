import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/local/tweet_templates_storage.dart';
import 'package:tx_manager_mobile/data/models/tweet_template_model.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';
import 'package:tx_manager_mobile/data/repositories/user_repository.dart';
import 'package:tx_manager_mobile/presentation/home/scheduled_posts_controller.dart';
import 'package:tx_manager_mobile/core/offline/queued_offline_exception.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  static const int _maxTweetLength = 280;
  static const int _warnThreshold = 260;

  bool _isThreadMode = false;
  final List<TextEditingController> _threadControllers = [
    TextEditingController(),
  ];

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _isLoading = false;
  String? _editingPostId; // Draft/edit mode

  @override
  void dispose() {
    _textController.dispose();
    for (final c in _threadControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _scheduledDate = pickedDate;
        _scheduledTime ??= const TimeOfDay(hour: 10, minute: 0);
      });
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 10, minute: 0),
    );

    if (pickedTime != null && mounted) {
      setState(() => _scheduledTime = pickedTime);
    }
  }

  Future<void> _createPost() async {
    final trimmed = _textController.text.trim();

    // Thread mode: create multiple posts as a reply-chain (server handles publishing order)
    final threadContents = _isThreadMode
        ? _threadControllers
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList()
        : const <String>[];

    if (_isThreadMode) {
      if (threadContents.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thread için en az 2 tweet gerekir.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (threadContents.any((t) => t.length > _maxTweetLength)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thread içindeki her tweet 280 karakteri geçemez.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else {
      if (trimmed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tweet içeriği girin')),
        );
        return;
      }

      if (trimmed.length > _maxTweetLength) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tweet 280 karakteri geçemez.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    if (!_isThreadMode && trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tweet içeriği girin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DateTime? scheduledFor;
      if (_scheduledDate != null && _scheduledTime != null) {
        scheduledFor = DateTime(
          _scheduledDate!.year,
          _scheduledDate!.month,
          _scheduledDate!.day,
          _scheduledTime!.hour,
          _scheduledTime!.minute,
        );
      }

      if (scheduledFor != null) {
        final minAllowed = DateTime.now().add(const Duration(minutes: 1));
        if (scheduledFor.isBefore(minAllowed)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Planlama zamanı geçmiş olamaz (en az 1 dk sonrası).',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }

      // Health-check: Planlama yapılıyorsa token durumunu kontrol et
      if (scheduledFor != null) {
        final status = await ref.read(userRepositoryProvider).getAuthStatus();
        if (status == null || status.requiresLogin) {
          if (mounted) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF252A34),
                title: const Text(
                  'Giriş gerekli',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Tweet planlamak için X hesabına tekrar giriş yapmalısın. Şimdi giriş yapmak ister misin?',
                  style: TextStyle(color: Colors.grey),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Giriş Yap'),
                  ),
                ],
              ),
            );

            if (proceed == true && mounted) {
              context.push('/auth_webview');
            }
          }
          return;
        }
      }

      if (_isThreadMode) {
        // Optimistic UI: add a local scheduled entry for the head tweet (first content)
        String? localId;
        if (scheduledFor != null) {
          localId = await ref
              .read(scheduledPostsProvider.notifier)
              .optimisticAdd(
                content: threadContents.first,
                scheduledForLocal: scheduledFor,
              );
        }

        await ref
            .read(postRepositoryProvider)
            .createThread(contents: threadContents, scheduledFor: scheduledFor);

        if (localId != null) {
          await ref
              .read(scheduledPostsProvider.notifier)
              .removeOptimistic(localId);
          // Refresh to pull server truth
          await ref.read(scheduledPostsProvider.notifier).refresh();
        }
      } else if (_editingPostId != null) {
        await ref
            .read(postRepositoryProvider)
            .updatePost(_editingPostId!, trimmed, scheduledFor);
      } else {
        // Optimistic UI for scheduled posts
        String? localId;
        if (scheduledFor != null) {
          localId = await ref
              .read(scheduledPostsProvider.notifier)
              .optimisticAdd(content: trimmed, scheduledForLocal: scheduledFor);
        }

        await ref
            .read(postRepositoryProvider)
            .createPost(content: trimmed, scheduledFor: scheduledFor);

        if (localId != null) {
          await ref
              .read(scheduledPostsProvider.notifier)
              .removeOptimistic(localId);
          await ref.read(scheduledPostsProvider.notifier).refresh();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isThreadMode
                  ? (scheduledFor != null
                        ? 'Thread başarıyla planlandı!'
                        : 'Thread taslak olarak kaydedildi!')
                  : (scheduledFor != null
                        ? (_editingPostId != null
                              ? 'Tweet yeniden planlandı!'
                              : 'Tweet başarıyla planlandı!')
                        : (_editingPostId != null
                              ? 'Taslak güncellendi!'
                              : 'Tweet taslak olarak kaydedildi!')),
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Formu temizle
        _textController.clear();
        setState(() {
          _scheduledDate = null;
          _scheduledTime = null;
          _editingPostId = null;
          if (_isThreadMode) {
            for (final c in _threadControllers) {
              c.clear();
            }
            // keep at least one controller
            while (_threadControllers.length > 1) {
              _threadControllers.removeLast().dispose();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is QueuedOfflineException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final tzOffset = DateTime.now().timeZoneOffset;
    final tzOffsetText =
        'UTC${tzOffset.isNegative ? '-' : '+'}${tzOffset.abs().inHours.toString().padLeft(2, '0')}:${(tzOffset.abs().inMinutes % 60).toString().padLeft(2, '0')}';
    final tzName = DateTime.now().timeZoneName;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Yeni Tweet',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _DraftPicker(
                        isEditing: _editingPostId != null,
                        onPick: (post) {
                          final id = post['id']?.toString();
                          if (id == null || id.isEmpty) return;

                          final content = (post['content'] ?? '').toString();
                          final localDt = DateTime.tryParse(
                            (post['scheduledFor'] ?? post['createdAt'] ?? '')
                                .toString(),
                          )?.toLocal();

                          setState(() {
                            _editingPostId = id;
                            _textController.text = content;
                            // Drafts typically have no scheduledFor; keep schedule empty unless present
                            if (post['scheduledFor'] != null &&
                                localDt != null) {
                              _scheduledDate = DateTime(
                                localDt.year,
                                localDt.month,
                                localDt.day,
                              );
                              _scheduledTime = TimeOfDay.fromDateTime(localDt);
                            } else {
                              _scheduledDate = null;
                              _scheduledTime = null;
                            }
                          });

                          FocusScope.of(context).requestFocus(FocusNode());
                        },
                        onClearEdit: () {
                          setState(() {
                            _editingPostId = null;
                            _scheduledDate = null;
                            _scheduledTime = null;
                          });
                          _textController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TemplatePicker(
                        getCurrentText: () => _textController.text.trim(),
                        onApply: (content) {
                          if (content.trim().isEmpty) return;
                          setState(() {
                            _editingPostId = null;
                            _scheduledDate = null;
                            _scheduledTime = null;
                            if (_isThreadMode) {
                              _threadControllers.first.text = content;
                            } else {
                              _textController.text = content;
                            }
                          });
                          FocusScope.of(context).requestFocus(FocusNode());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.format_list_bulleted,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Thread modu',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isThreadMode,
                        onChanged: (v) {
                          setState(() {
                            _isThreadMode = v;
                            _editingPostId =
                                null; // thread & draft-edit don't mix for now
                            _scheduledDate = null;
                            _scheduledTime = null;
                            _textController.clear();
                            for (final c in _threadControllers) {
                              c.clear();
                            }
                            while (_threadControllers.length > 1) {
                              _threadControllers.removeLast().dispose();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: _isThreadMode
                      ? Column(
                          children: [
                            for (int i = 0; i < _threadControllers.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                  top: i == 0 ? 12 : 8,
                                  bottom: 8,
                                ),
                                child: _ThreadTweetField(
                                  index: i,
                                  controller: _threadControllers[i],
                                  maxLen: _maxTweetLength,
                                  warnThreshold: _warnThreshold,
                                  onRemove: _threadControllers.length > 1
                                      ? () {
                                          setState(() {
                                            final c = _threadControllers
                                                .removeAt(i);
                                            c.dispose();
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _threadControllers.add(
                                        TextEditingController(),
                                      );
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  label: const Text('Tweet ekle'),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : TextField(
                          controller: _textController,
                          maxLines: 8,
                          maxLength: _maxTweetLength,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(_maxTweetLength),
                          ],
                          buildCounter:
                              (
                                context, {
                                required int currentLength,
                                required bool isFocused,
                                required int? maxLength,
                              }) {
                                final max = maxLength ?? _maxTweetLength;
                                final remaining = max - currentLength;

                                Color color = Colors.grey[600]!;
                                if (currentLength >= _warnThreshold &&
                                    currentLength < max) {
                                  color = Colors.orangeAccent;
                                } else if (currentLength >= max) {
                                  color = Colors.redAccent;
                                }

                                final text = remaining <= 20
                                    ? '$currentLength/$max (kalan: $remaining)'
                                    : '$currentLength/$max';

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    right: 12,
                                    bottom: 10,
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tweet içeriğinizi yazın...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                // Schedule Options
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Planlama (Opsiyonel)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Saat dilimi: $tzName ($tzOffsetText)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _scheduledDate != null
                                          ? dateFormat.format(_scheduledDate!)
                                          : 'Tarih seç',
                                      style: TextStyle(
                                        color: _scheduledDate != null
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _selectTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _scheduledTime != null
                                          ? _scheduledTime!.format(context)
                                          : 'Saat seç',
                                      style: TextStyle(
                                        color: _scheduledTime != null
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_scheduledDate != null || _scheduledTime != null) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _scheduledDate = null;
                              _scheduledTime = null;
                            });
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Planlamayı kaldır'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textController,
                  builder: (context, value, _) {
                    final text = value.text.trim();
                    final canSubmitSingle =
                        !_isLoading &&
                        text.isNotEmpty &&
                        text.length <= _maxTweetLength;
                    final canSubmitThread =
                        !_isLoading &&
                        _threadControllers
                                .map((c) => c.text.trim())
                                .where((t) => t.isNotEmpty)
                                .length >=
                            2 &&
                        _threadControllers
                            .map((c) => c.text.trim())
                            .where((t) => t.isNotEmpty)
                            .every((t) => t.length <= _maxTweetLength);

                    final canSubmit = _isThreadMode
                        ? canSubmitThread
                        : canSubmitSingle;

                    return ElevatedButton(
                      onPressed: canSubmit ? _createPost : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppTheme.primaryColor
                            .withValues(alpha: 0.35),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isThreadMode
                                  ? (_scheduledDate != null &&
                                            _scheduledTime != null
                                        ? 'Thread\'i Planla'
                                        : 'Thread Taslağı Kaydet')
                                  : (_scheduledDate != null &&
                                            _scheduledTime != null
                                        ? (_editingPostId != null
                                              ? 'Yeniden Planla'
                                              : 'Tweet\'i Planla')
                                        : (_editingPostId != null
                                              ? 'Taslağı Güncelle'
                                              : 'Taslak Olarak Kaydet')),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadTweetField extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final int maxLen;
  final int warnThreshold;
  final VoidCallback? onRemove;

  const _ThreadTweetField({
    required this.index,
    required this.controller,
    required this.maxLen,
    required this.warnThreshold,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Text(
                  'Tweet #${index + 1}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Kaldır',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                  ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            maxLines: 5,
            maxLength: maxLen,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            inputFormatters: [LengthLimitingTextInputFormatter(maxLen)],
            buildCounter:
                (
                  context, {
                  required int currentLength,
                  required bool isFocused,
                  required int? maxLength,
                }) {
                  final max = maxLength ?? maxLen;
                  final remaining = max - currentLength;
                  Color color = Colors.grey[600]!;
                  if (currentLength >= warnThreshold && currentLength < max) {
                    color = Colors.orangeAccent;
                  } else if (currentLength >= max) {
                    color = Colors.redAccent;
                  }
                  final text = remaining <= 20
                      ? '$currentLength/$max (kalan: $remaining)'
                      : '$currentLength/$max';
                  return Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 10),
                    child: Text(
                      text,
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  );
                },
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Thread parçası...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftPicker extends ConsumerWidget {
  final void Function(Map<String, dynamic> post) onPick;
  final VoidCallback onClearEdit;
  final bool isEditing;

  const _DraftPicker({
    required this.onPick,
    required this.onClearEdit,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF252A34),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => const _DraftsBottomSheet(),
              ).then((value) {
                if (value is Map<String, dynamic>) {
                  onPick(value);
                }
              });
            },
            icon: const Icon(Icons.notes, color: Colors.white),
            label: const Text('Uygulama taslakları'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (isEditing) ...[
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Düzenlemeyi bırak',
            onPressed: onClearEdit,
            icon: const Icon(Icons.close, color: Colors.redAccent),
          ),
        ],
      ],
    );
  }
}

class _DraftsBottomSheet extends ConsumerWidget {
  const _DraftsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(_draftsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Uygulama taslakları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: () => ref.invalidate(_draftsProvider),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Not: X (Twitter) API taslakları listelemeye izin vermez. Bu liste, TX Asistan içinde “Taslak olarak kaydet” dediğin tweetleri gösterir.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            draftsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Hata: $e',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              data: (drafts) {
                if (drafts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Taslak bulunamadı.\nİpucu: Planlama seçmeden “Taslak Olarak Kaydet” deyip burada görebilirsin.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Keep it short; bottom sheet height will expand if needed.
                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: drafts.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10),
                    itemBuilder: (context, i) {
                      final post = Map<String, dynamic>.from(drafts[i] as Map);
                      final content = (post['content'] ?? '').toString();
                      final createdAt = DateTime.tryParse(
                        (post['createdAt'] ?? '').toString(),
                      )?.toLocal();
                      final createdText = createdAt != null
                          ? DateFormat('dd MMM HH:mm').format(createdAt)
                          : '';

                      return ListTile(
                        onTap: () => Navigator.pop(context, post),
                        title: Text(
                          content.isEmpty ? '(Boş taslak)' : content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: createdText.isEmpty
                            ? null
                            : Text(
                                createdText,
                                style: const TextStyle(color: Colors.white54),
                              ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final _draftsProvider = FutureProvider<List<dynamic>>((ref) async {
  // PostStatus.Draft = 0
  return ref.read(postRepositoryProvider).getPosts(status: '0');
});

final _templatesStorageProvider = Provider<TweetTemplatesStorage>((ref) {
  return TweetTemplatesStorage();
});

final _templatesProvider = FutureProvider<List<TweetTemplateModel>>((
  ref,
) async {
  return ref.read(_templatesStorageProvider).loadTemplates();
});

class _TemplatePicker extends ConsumerWidget {
  final String Function() getCurrentText;
  final void Function(String content) onApply;

  const _TemplatePicker({required this.getCurrentText, required this.onApply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        await showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF252A34),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => _TemplatesBottomSheet(currentText: getCurrentText()),
        ).then((value) {
          if (value is String) onApply(value);
        });
      },
      icon: const Icon(Icons.bookmark_outline, color: Colors.white),
      label: const Text('Şablonlar'),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _TemplatesBottomSheet extends ConsumerWidget {
  final String currentText;

  const _TemplatesBottomSheet({required this.currentText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(_templatesProvider);

    Future<void> createTemplate() async {
      final text = currentText.trim();
      if (text.isEmpty) return;

      final controller = TextEditingController();
      final title = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF252A34),
          title: const Text(
            'Şablon kaydet',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Şablon adı',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      );

      if (title == null || title.trim().isEmpty) return;

      final template = TweetTemplateModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.trim(),
        content: text,
        createdAt: DateTime.now(),
      );

      await ref.read(_templatesStorageProvider).addTemplate(template);
      ref.invalidate(_templatesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şablon kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Şablonlar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: () => ref.invalidate(_templatesProvider),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (currentText.trim().isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: createTemplate,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Bu tweet’i şablon olarak kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            templatesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Hata: $e',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              data: (templates) {
                if (templates.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Şablon bulunamadı.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10),
                    itemBuilder: (context, i) {
                      final t = templates[i];
                      return ListTile(
                        onTap: () => Navigator.pop(context, t.content),
                        title: Text(
                          t.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          t.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: IconButton(
                          tooltip: 'Sil',
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            await ref
                                .read(_templatesStorageProvider)
                                .deleteTemplate(t.id);
                            ref.invalidate(_templatesProvider);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
