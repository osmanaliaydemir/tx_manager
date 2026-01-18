import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/suggestion_repository.dart';
import 'package:tx_manager_mobile/domain/entities/content_suggestion.dart';
import 'package:tx_manager_mobile/presentation/home/scheduled_posts_controller.dart';
import 'package:tx_manager_mobile/core/offline/queued_offline_exception.dart';

final suggestionsProvider = FutureProvider<List<ContentSuggestion>>((
  ref,
) async {
  return ref
      .read(suggestionRepositoryProvider)
      .getSuggestions(status: 'Pending');
});

class AiSuggestionsScreen extends ConsumerWidget {
  const AiSuggestionsScreen({super.key});

  Future<DateTime?> _pickLocalDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestionsProvider);
    final formatter = DateFormat('dd MMM HH:mm');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Öneriler'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Öneri üret',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () async {
              try {
                await ref
                    .read(suggestionRepositoryProvider)
                    .triggerGeneration();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Öneri üretimi tetiklendi (arka planda).'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                ref.invalidate(suggestionsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(suggestionsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Hata: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Öneri yok.\nİpucu: sağ üstten “Öneri üret”e bas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async => ref.invalidate(suggestionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final s = items[i];
                final dateLocal = s.generatedAtUtc.toLocal();

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
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formatter.format(dateLocal),
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              s.riskAssessment,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.suggestedText,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.35,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.rationale,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Etki: ${s.estimatedImpact}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  final policy =
                                      await showModalBottomSheet<
                                        ({
                                          bool excludeWeekends,
                                          int startHour,
                                          int endHour,
                                        })?
                                      >(
                                        context: context,
                                        backgroundColor: const Color(
                                          0xFF252A34,
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        builder: (ctx) {
                                          bool excludeWeekends = true;
                                          int startHour = 9;
                                          int endHour = 18;

                                          return StatefulBuilder(
                                            builder: (ctx, setState) {
                                              Future<void> pickStart() async {
                                                final picked =
                                                    await showTimePicker(
                                                      context: ctx,
                                                      initialTime: TimeOfDay(
                                                        hour: startHour,
                                                        minute: 0,
                                                      ),
                                                    );
                                                if (picked == null) return;
                                                setState(
                                                  () => startHour = picked.hour,
                                                );
                                              }

                                              Future<void> pickEnd() async {
                                                final picked =
                                                    await showTimePicker(
                                                      context: ctx,
                                                      initialTime: TimeOfDay(
                                                        hour: endHour,
                                                        minute: 0,
                                                      ),
                                                    );
                                                if (picked == null) return;
                                                setState(
                                                  () => endHour = picked.hour,
                                                );
                                              }

                                              return SafeArea(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      const Text(
                                                        'Auto planlama',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      SwitchListTile(
                                                        value: excludeWeekends,
                                                        onChanged: (v) => setState(
                                                          () =>
                                                              excludeWeekends =
                                                                  v,
                                                        ),
                                                        title: const Text(
                                                          'Hafta sonu hariç',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        subtitle: Text(
                                                          'Cumartesi/Pazar günlerine planlama yapma',
                                                          style: TextStyle(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                        'Tercih edilen saat aralığı',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: OutlinedButton.icon(
                                                              onPressed:
                                                                  pickStart,
                                                              icon: const Icon(
                                                                Icons
                                                                    .access_time,
                                                                color: Colors
                                                                    .white,
                                                                size: 18,
                                                              ),
                                                              label: Text(
                                                                'Başlangıç: ${startHour.toString().padLeft(2, '0')}:00',
                                                              ),
                                                              style: OutlinedButton.styleFrom(
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                side: BorderSide(
                                                                  color: Colors
                                                                      .white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.18,
                                                                      ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: OutlinedButton.icon(
                                                              onPressed:
                                                                  pickEnd,
                                                              icon: const Icon(
                                                                Icons
                                                                    .access_time,
                                                                color: Colors
                                                                    .white,
                                                                size: 18,
                                                              ),
                                                              label: Text(
                                                                'Bitiş: ${endHour.toString().padLeft(2, '0')}:00',
                                                              ),
                                                              style: OutlinedButton.styleFrom(
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                side: BorderSide(
                                                                  color: Colors
                                                                      .white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.18,
                                                                      ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              AppTheme
                                                                  .primaryColor,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                        onPressed: () {
                                                          if (startHour >=
                                                              endHour) {
                                                            ScaffoldMessenger.of(
                                                              ctx,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  'Saat aralığı geçersiz (başlangıç < bitiş olmalı).',
                                                                ),
                                                                backgroundColor:
                                                                    Colors
                                                                        .redAccent,
                                                              ),
                                                            );
                                                            return;
                                                          }
                                                          Navigator.pop(ctx, (
                                                            excludeWeekends:
                                                                excludeWeekends,
                                                            startHour:
                                                                startHour,
                                                            endHour: endHour,
                                                          ));
                                                        },
                                                        child: const Text(
                                                          'Planla',
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                          'İptal',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );

                                  if (policy == null) return;
                                  await ref
                                      .read(suggestionRepositoryProvider)
                                      .acceptSuggestion(
                                        s.id,
                                        auto: true,
                                        excludeWeekends: policy.excludeWeekends,
                                        preferredStartLocalHour:
                                            policy.startHour,
                                        preferredEndLocalHour: policy.endHour,
                                      );
                                  ref.invalidate(suggestionsProvider);
                                  ref.invalidate(scheduledPostsProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Auto planlandı.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      e is QueuedOfflineException
                                          ? SnackBar(
                                              content: Text(e.message),
                                              backgroundColor: Colors.orange,
                                            )
                                          : SnackBar(
                                              content: Text('Hata: $e'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.schedule,
                                color: Colors.white,
                              ),
                              label: const Text('Auto planla'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () async {
                              final local = await _pickLocalDateTime(context);
                              if (local == null) return;
                              try {
                                await ref
                                    .read(suggestionRepositoryProvider)
                                    .acceptSuggestion(
                                      s.id,
                                      auto: false,
                                      scheduledForLocal: local,
                                    );
                                ref.invalidate(suggestionsProvider);
                                ref.invalidate(scheduledPostsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Planlandı: ${formatter.format(local)}',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    e is QueuedOfflineException
                                        ? SnackBar(
                                            content: Text(e.message),
                                            backgroundColor: Colors.orange,
                                          )
                                        : SnackBar(
                                            content: Text('Hata: $e'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Text('Saat seç'),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: 'Reddet',
                            onPressed: () async {
                              try {
                                await ref
                                    .read(suggestionRepositoryProvider)
                                    .rejectSuggestion(s.id);
                                ref.invalidate(suggestionsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reddedildi.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    e is QueuedOfflineException
                                        ? SnackBar(
                                            content: Text(e.message),
                                            backgroundColor: Colors.orange,
                                          )
                                        : SnackBar(
                                            content: Text('Hata: $e'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
