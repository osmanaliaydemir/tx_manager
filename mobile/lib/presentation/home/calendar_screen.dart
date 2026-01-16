import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';
import 'package:tx_manager_mobile/presentation/home/posts_screen.dart';
import 'package:tx_manager_mobile/presentation/home/scheduled_posts_controller.dart';

enum _CalendarViewMode { month, week, day }

enum _DropAction { keepTime, pickTime, cancel }

enum _EditResult { save, delete, cancel }

class _CalendarEvent {
  final Map<String, dynamic> post;
  final String status;
  final DateTime localDateTime;

  const _CalendarEvent({
    required this.post,
    required this.status,
    required this.localDateTime,
  });
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  static const int _dayStartHour = 6;
  static const int _dayEndHourInclusive = 23;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _focusedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _rescheduleByDrop(
    Map<String, dynamic> post,
    DateTime day,
  ) async {
    final existingLocal = _extractLocalDateTime(post);
    final originalTime = existingLocal != null
        ? TimeOfDay.fromDateTime(existingLocal)
        : const TimeOfDay(hour: 10, minute: 0);

    final action = await showModalBottomSheet<_DropAction>(
      context: context,
      backgroundColor: const Color(0xFF252A34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Yeniden planla',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hedef gün: ${DateFormat('dd MMM yyyy').format(day)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 16),
                _BottomSheetButton(
                  icon: Icons.schedule,
                  title: 'Saati koru',
                  subtitle: 'Saat: ${originalTime.format(context)}',
                  color: Colors.green,
                  onTap: () => Navigator.pop(context, _DropAction.keepTime),
                ),
                const SizedBox(height: 10),
                _BottomSheetButton(
                  icon: Icons.access_time,
                  title: 'Saat seç',
                  subtitle: 'Yeni bir saat belirle',
                  color: AppTheme.primaryColor,
                  onTap: () => Navigator.pop(context, _DropAction.pickTime),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context, _DropAction.cancel),
                  child: const Text(
                    'İptal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null || action == _DropAction.cancel) return;

    TimeOfDay finalTime = originalTime;
    if (action == _DropAction.pickTime) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: originalTime,
      );
      if (pickedTime == null || !mounted) return;
      finalTime = pickedTime;
    }

    final newDateTime = DateTime(
      day.year,
      day.month,
      day.day,
      finalTime.hour,
      finalTime.minute,
    );

    await _reschedulePost(post, newDateTime);
  }

  Future<void> _reschedulePost(
    Map<String, dynamic> post,
    DateTime newLocalDateTime,
  ) async {
    final now = DateTime.now();

    // Client-side guard: don't allow scheduling in the past (>= 1 minute in the future)
    if (newLocalDateTime.isBefore(now.add(const Duration(minutes: 1)))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçmişe planlama yapılamaz (en az 1 dk sonrası).'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      await ref
          .read(postRepositoryProvider)
          .updatePost(post['id'], post['content'] ?? '', newLocalDateTime);

      ref.invalidate(scheduledPostsProvider);
      ref.invalidate(postsProvider('2'));
      ref.invalidate(postsProvider('3'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Yeniden planlandı: ${DateFormat('dd MMM HH:mm').format(newLocalDateTime)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planlama hatası: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _extractLocalDateTime(Map<String, dynamic> post) {
    final dateStr = post['scheduledFor'] ?? post['createdAt'];
    final dt = DateTime.tryParse(dateStr ?? '');
    return dt?.toLocal();
  }

  DateTime _startOfWeek(DateTime date) {
    // Monday as start of week
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case '2':
        return Colors.green;
      case '3':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  Future<void> _showPublishedDetails(Map<String, dynamic> post) async {
    final content = (post['content'] ?? '').toString();
    final dateStr = post['scheduledFor'] ?? post['createdAt'];
    final date = DateTime.tryParse(dateStr ?? '')?.toLocal();
    final formatter = DateFormat('dd MMM yyyy HH:mm');

    final likes = (post['likeCount'] ?? 0).toString();
    final retweets = (post['retweetCount'] ?? 0).toString();
    final views = (post['impressionCount'] ?? 0).toString();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF252A34),
        title: const Text(
          'Yayınlanan Tweet',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (date != null)
                Text(
                  formatter.format(date),
                  style: const TextStyle(color: Colors.green),
                ),
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip(icon: Icons.visibility, value: views),
                  _StatChip(icon: Icons.favorite, value: likes),
                  _StatChip(icon: Icons.repeat, value: retweets),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialogForPost(
    Map<String, dynamic> post,
    String status,
  ) async {
    // Only scheduled/failed are editable
    if (status == '2') {
      await _showPublishedDetails(post);
      return;
    }

    final contentController = TextEditingController(
      text: post['content'] ?? '',
    );
    DateTime scheduledDate =
        _extractLocalDateTime(post) ??
        DateTime.now().add(const Duration(days: 1));
    TimeOfDay scheduledTime = TimeOfDay.fromDateTime(scheduledDate);

    if (!mounted) return;

    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final dateStr = DateFormat('dd MMM yyyy').format(scheduledDate);
          final timeStr = scheduledTime.format(dialogContext);

          return AlertDialog(
            backgroundColor: const Color(0xFF252A34),
            title: const Text(
              'Gönderiyi Düzenle',
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
                      'Tarih',
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
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (dt != null) setState(() => scheduledDate = dt);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Saat',
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
                onPressed: () =>
                    Navigator.pop(dialogContext, _EditResult.cancel),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _EditResult.delete),
                child: const Text(
                  'Sil',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                onPressed: () => Navigator.pop(dialogContext, _EditResult.save),
                child: const Text(
                  'Kaydet',
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

    if (!mounted || result == null || result == _EditResult.cancel) return;

    if (result == _EditResult.delete) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF252A34),
          title: const Text(
            'Gönderiyi Sil',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Bu gönderiyi silmek istediğinize emin misiniz?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Sil',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await ref.read(postRepositoryProvider).deletePost(post['id']);
        ref.invalidate(scheduledPostsProvider);
        ref.invalidate(postsProvider('2'));
        ref.invalidate(postsProvider('3'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gönderi silindi'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      return;
    }

    // save
    final newDateTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );
    await _reschedulePost(
      post..['content'] = contentController.text,
      newDateTime,
    );
  }

  Map<String, int> _countByDayInRange(
    List<dynamic> posts,
    DateTime start,
    DateTime endExclusive,
  ) {
    final map = <String, int>{};
    final keyFmt = DateFormat('yyyy-MM-dd');
    for (final p in posts) {
      final postMap = Map<String, dynamic>.from(p as Map);
      final dt = _extractLocalDateTime(postMap);
      if (dt == null) continue;
      if (dt.isBefore(start) || !dt.isBefore(endExclusive)) continue;
      final key = keyFmt.format(dt);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> _countByDay(
    List<dynamic> posts,
    DateTime selectedMonth,
    String status,
  ) {
    // Key: yyyy-MM-dd
    final map = <String, int>{};
    for (final p in posts) {
      final dateStr = p['scheduledFor'] ?? p['createdAt'];
      final dt = DateTime.tryParse(dateStr ?? '')?.toLocal();
      if (dt == null) continue;
      if (dt.year != selectedMonth.year || dt.month != selectedMonth.month) {
        continue;
      }
      final key = DateFormat('yyyy-MM-dd').format(dt);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy');
    final monthFormatter = DateFormat('MMMM yyyy', 'tr_TR');
    final weekStart = _startOfWeek(_selectedDate);
    final weekEndExclusive = weekStart.add(const Duration(days: 7));

    final scheduledAsync = ref.watch(scheduledPostsProvider);
    final publishedAsync = ref.watch(postsProvider('2'));
    final failedAsync = ref.watch(postsProvider('3'));

    List<_CalendarEvent> buildDayEvents(
      AsyncValue<List<dynamic>> async,
      String status,
    ) {
      return async.maybeWhen(
        data: (posts) {
          return posts
              .map((p) => Map<String, dynamic>.from(p as Map))
              .map((p) {
                final dt = _extractLocalDateTime(p);
                if (dt == null) return null;
                return _CalendarEvent(
                  post: p,
                  status: status,
                  localDateTime: dt,
                );
              })
              .whereType<_CalendarEvent>()
              .where((e) => _isSameLocalDay(e.localDateTime, _selectedDate))
              .toList();
        },
        orElse: () => const [],
      );
    }

    final dayEvents = <_CalendarEvent>[
      ...buildDayEvents(scheduledAsync, '1'),
      ...buildDayEvents(publishedAsync, '2'),
      ...buildDayEvents(failedAsync, '3'),
    ]..sort((a, b) => a.localDateTime.compareTo(b.localDateTime));

    final eventsByHour = <int, List<_CalendarEvent>>{};
    for (final e in dayEvents) {
      eventsByHour.putIfAbsent(e.localDateTime.hour, () => []).add(e);
    }

    final scheduledCounts = scheduledAsync.maybeWhen(
      data: (posts) => _countByDay(posts, _focusedMonth, '1'),
      orElse: () => const <String, int>{},
    );
    final publishedCounts = publishedAsync.maybeWhen(
      data: (posts) => _countByDay(posts, _focusedMonth, '2'),
      orElse: () => const <String, int>{},
    );
    final failedCounts = failedAsync.maybeWhen(
      data: (posts) => _countByDay(posts, _focusedMonth, '3'),
      orElse: () => const <String, int>{},
    );

    final scheduledWeekCounts = scheduledAsync.maybeWhen(
      data: (posts) => _countByDayInRange(posts, weekStart, weekEndExclusive),
      orElse: () => const <String, int>{},
    );
    final publishedWeekCounts = publishedAsync.maybeWhen(
      data: (posts) => _countByDayInRange(posts, weekStart, weekEndExclusive),
      orElse: () => const <String, int>{},
    );
    final failedWeekCounts = failedAsync.maybeWhen(
      data: (posts) => _countByDayInRange(posts, weekStart, weekEndExclusive),
      orElse: () => const <String, int>{},
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Takvim'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Tarih seç',
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(scheduledPostsProvider);
              ref.invalidate(postsProvider('2'));
              ref.invalidate(postsProvider('3'));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(
                children: [
                  SegmentedButton<_CalendarViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: _CalendarViewMode.month,
                        label: Text('Ay'),
                        icon: Icon(Icons.calendar_view_month),
                      ),
                      ButtonSegment(
                        value: _CalendarViewMode.week,
                        label: Text('Hafta'),
                        icon: Icon(Icons.view_week),
                      ),
                      ButtonSegment(
                        value: _CalendarViewMode.day,
                        label: Text('Gün'),
                        icon: Icon(Icons.view_day),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (s) =>
                        setState(() => _viewMode = s.first),
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.primaryColor.withValues(alpha: 0.18);
                        }
                        return Colors.black.withValues(alpha: 0.2);
                      }),
                      side: WidgetStateProperty.all(
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        tooltip: _viewMode == _CalendarViewMode.week
                            ? 'Önceki hafta'
                            : _viewMode == _CalendarViewMode.day
                            ? 'Önceki gün'
                            : 'Önceki ay',
                        onPressed: () {
                          setState(() {
                            if (_viewMode == _CalendarViewMode.month) {
                              _focusedMonth = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month - 1,
                                1,
                              );
                            } else if (_viewMode == _CalendarViewMode.week) {
                              _selectedDate = _selectedDate.subtract(
                                const Duration(days: 7),
                              );
                              _focusedMonth = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                1,
                              );
                            } else {
                              _selectedDate = _selectedDate.subtract(
                                const Duration(days: 1),
                              );
                              _focusedMonth = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                1,
                              );
                            }
                          });
                        },
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _viewMode == _CalendarViewMode.week
                                ? '${DateFormat('dd MMM', 'tr_TR').format(weekStart)} - ${DateFormat('dd MMM', 'tr_TR').format(weekStart.add(const Duration(days: 6)))}'
                                : _viewMode == _CalendarViewMode.day
                                ? formatter.format(_selectedDate)
                                : monthFormatter.format(_focusedMonth),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _viewMode == _CalendarViewMode.week
                            ? 'Sonraki hafta'
                            : _viewMode == _CalendarViewMode.day
                            ? 'Sonraki gün'
                            : 'Sonraki ay',
                        onPressed: () {
                          setState(() {
                            if (_viewMode == _CalendarViewMode.month) {
                              _focusedMonth = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month + 1,
                                1,
                              );
                            } else if (_viewMode == _CalendarViewMode.week) {
                              _selectedDate = _selectedDate.add(
                                const Duration(days: 7),
                              );
                              _focusedMonth = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                1,
                              );
                            } else {
                              _selectedDate = _selectedDate.add(
                                const Duration(days: 1),
                              );
                              _focusedMonth = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                1,
                              );
                            }
                          });
                        },
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_viewMode == _CalendarViewMode.month) ...[
                    _WeekdayHeader(),
                    const SizedBox(height: 8),
                    _MonthGrid(
                      focusedMonth: _focusedMonth,
                      selectedDate: _selectedDate,
                      isSameDay: _isSameLocalDay,
                      scheduledCounts: scheduledCounts,
                      publishedCounts: publishedCounts,
                      failedCounts: failedCounts,
                      onSelectDay: (day) {
                        setState(() => _selectedDate = day);
                      },
                      onDropPost: (post, day) => _rescheduleByDrop(post, day),
                    ),
                  ] else if (_viewMode == _CalendarViewMode.week) ...[
                    _WeekdayHeader(),
                    const SizedBox(height: 8),
                    _WeekStrip(
                      weekStart: weekStart,
                      selectedDate: _selectedDate,
                      isSameDay: _isSameLocalDay,
                      scheduledCounts: scheduledWeekCounts,
                      publishedCounts: publishedWeekCounts,
                      failedCounts: failedWeekCounts,
                      onSelectDay: (d) => setState(() => _selectedDate = d),
                      onDropPost: (post, day) => _rescheduleByDrop(post, day),
                    ),
                  ] else ...[
                    _DayTimeline(
                      day: _selectedDate,
                      startHour: _dayStartHour,
                      endHourInclusive: _dayEndHourInclusive,
                      onDropAt: (post, dt) => _reschedulePost(post, dt),
                      eventsByHour: eventsByHour,
                      onTapEvent: (e) =>
                          _showEditDialogForPost(e.post, e.status),
                      colorForStatus: _colorForStatus,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.event,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Seçili gün: ${formatter.format(_selectedDate)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDate,
                        child: const Text('Tarih seç'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: AppTheme.primaryColor,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'Zamanlanan'),
                      Tab(text: 'Yayınlanan'),
                      Tab(text: 'Başarısız'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _DayFilteredList(
                          selectedDate: _selectedDate,
                          postsAsync: scheduledAsync,
                          isSameDay: _isSameLocalDay,
                          emptyText: 'Bu gün için zamanlanan tweet yok.',
                          status: '1',
                          draggable: true,
                        ),
                        _DayFilteredList(
                          selectedDate: _selectedDate,
                          postsAsync: publishedAsync,
                          isSameDay: _isSameLocalDay,
                          emptyText: 'Bu gün için yayınlanan tweet yok.',
                          status: '2',
                          draggable: false,
                        ),
                        _DayFilteredList(
                          selectedDate: _selectedDate,
                          postsAsync: failedAsync,
                          isSameDay: _isSameLocalDay,
                          emptyText: 'Bu gün için başarısız tweet yok.',
                          status: '3',
                          draggable: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayFilteredList extends ConsumerWidget {
  final DateTime selectedDate;
  final AsyncValue<List<dynamic>> postsAsync;
  final bool Function(DateTime a, DateTime b) isSameDay;
  final String emptyText;
  final String status;
  final bool draggable;

  const _DayFilteredList({
    required this.selectedDate,
    required this.postsAsync,
    required this.isSameDay,
    required this.emptyText,
    required this.status,
    required this.draggable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (posts) {
        DateTime? parseDate(Map<String, dynamic> post) {
          final dateStr = post['scheduledFor'] ?? post['createdAt'];
          final dt = DateTime.tryParse(dateStr ?? '');
          return dt?.toLocal();
        }

        final filtered = posts
            .map((p) => Map<String, dynamic>.from(p as Map))
            .where((p) {
              final dt = parseDate(p);
              if (dt == null) return false;
              return isSameDay(dt, selectedDate);
            })
            .toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async => ref.invalidate(postsProvider(status)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = filtered[index];
              final card = PostCard(post: post, status: status);
              if (!draggable) return card;
              return LongPressDraggable<Map<String, dynamic>>(
                data: post,
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 48,
                    child: Opacity(opacity: 0.85, child: card),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: card),
                child: card,
              );
            },
          ),
        );
      },
    );
  }
}

class _BottomSheetButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BottomSheetButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final bool Function(DateTime a, DateTime b) isSameDay;
  final Map<String, int> scheduledCounts;
  final Map<String, int> publishedCounts;
  final Map<String, int> failedCounts;
  final ValueChanged<DateTime> onSelectDay;
  final void Function(Map<String, dynamic> post, DateTime day) onDropPost;

  const _WeekStrip({
    required this.weekStart,
    required this.selectedDate,
    required this.isSameDay,
    required this.scheduledCounts,
    required this.publishedCounts,
    required this.failedCounts,
    required this.onSelectDay,
    required this.onDropPost,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final keyFmt = DateFormat('yyyy-MM-dd');

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: DragTarget<Map<String, dynamic>>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) => onDropPost(details.data, day),
                builder: (context, candidateData, rejectedData) {
                  final key = keyFmt.format(day);
                  final s = scheduledCounts[key] ?? 0;
                  final p = publishedCounts[key] ?? 0;
                  final f = failedCounts[key] ?? 0;
                  final isSelected = isSameDay(day, selectedDate);
                  final isToday = isSameDay(day, DateTime.now());
                  final isDropping = candidateData.isNotEmpty;

                  return InkWell(
                    onTap: () => onSelectDay(day),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.18)
                            : AppTheme.surfaceColor.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDropping
                              ? Colors.greenAccent.withValues(alpha: 0.7)
                              : isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.06),
                          width: isDropping ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _Badges(scheduled: s, published: p, failed: f),
                          if (isToday) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _DayTimeline extends StatelessWidget {
  final DateTime day;
  final int startHour;
  final int endHourInclusive;
  final void Function(Map<String, dynamic> post, DateTime newLocalDateTime)
  onDropAt;
  final Map<int, List<_CalendarEvent>> eventsByHour;
  final void Function(_CalendarEvent event) onTapEvent;
  final Color Function(String status) colorForStatus;

  const _DayTimeline({
    required this.day,
    required this.startHour,
    required this.endHourInclusive,
    required this.onDropAt,
    required this.eventsByHour,
    required this.onTapEvent,
    required this.colorForStatus,
  });

  @override
  Widget build(BuildContext context) {
    final safeDay = DateTime(day.year, day.month, day.day);
    final hours = List.generate(
      endHourInclusive - startHour + 1,
      (i) => startHour + i,
    );

    return Container(
      height: 260,
      padding: const EdgeInsets.only(top: 4),
      child: ListView.separated(
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final hour = hours[index];
          final slotTime = DateTime(
            safeDay.year,
            safeDay.month,
            safeDay.day,
            hour,
            0,
          );

          final isNowLine =
              DateTime.now().year == safeDay.year &&
              DateTime.now().month == safeDay.month &&
              DateTime.now().day == safeDay.day &&
              DateTime.now().hour == hour;

          final events = eventsByHour[hour] ?? const <_CalendarEvent>[];

          return DragTarget<Map<String, dynamic>>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) => onDropAt(details.data, slotTime),
            builder: (context, candidate, rejected) {
              final isDropping = candidate.isNotEmpty;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDropping
                              ? Colors.greenAccent.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.06),
                          width: isDropping ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                size: 16,
                                color: isDropping
                                    ? Colors.greenAccent
                                    : Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isDropping
                                      ? 'Bırak → ${DateFormat('HH:mm').format(slotTime)}'
                                      : (events.isEmpty
                                            ? 'Buraya sürükle-bırak'
                                            : 'Etkinlikler'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (isNowLine)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Şimdi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (events.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _EventChips(
                              events: events,
                              onTap: onTapEvent,
                              colorForStatus: colorForStatus,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EventChips extends StatelessWidget {
  final List<_CalendarEvent> events;
  final void Function(_CalendarEvent event) onTap;
  final Color Function(String status) colorForStatus;

  const _EventChips({
    required this.events,
    required this.onTap,
    required this.colorForStatus,
  });

  @override
  Widget build(BuildContext context) {
    final visible = events.take(3).toList();
    final remaining = events.length - visible.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in visible)
          _EventChip(
            text: (e.post['content'] ?? '').toString(),
            color: colorForStatus(e.status),
            onTap: () => onTap(e),
          ),
        if (remaining > 0)
          _EventChip(
            text: '+$remaining',
            color: Colors.white.withValues(alpha: 0.35),
            onTap: () {},
          ),
      ],
    );
  }
}

class _EventChip extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _EventChip({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final bool Function(DateTime a, DateTime b) isSameDay;
  final Map<String, int> scheduledCounts;
  final Map<String, int> publishedCounts;
  final Map<String, int> failedCounts;
  final ValueChanged<DateTime> onSelectDay;
  final void Function(Map<String, dynamic> post, DateTime day) onDropPost;

  const _MonthGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.isSameDay,
    required this.scheduledCounts,
    required this.publishedCounts,
    required this.failedCounts,
    required this.onSelectDay,
    required this.onDropPost,
  });

  @override
  Widget build(BuildContext context) {
    final start = _firstDayOfGrid(focusedMonth);
    final days = List.generate(42, (i) => start.add(Duration(days: i)));
    final keyFmt = DateFormat('yyyy-MM-dd');

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final inMonth =
            day.month == focusedMonth.month && day.year == focusedMonth.year;
        final isSelected = isSameDay(day, selectedDate);
        final isToday = isSameDay(day, DateTime.now());
        final key = keyFmt.format(day);

        final s = scheduledCounts[key] ?? 0;
        final p = publishedCounts[key] ?? 0;
        final f = failedCounts[key] ?? 0;

        return DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) => onDropPost(details.data, day),
          builder: (context, candidateData, rejectedData) {
            final isDropping = candidateData.isNotEmpty;
            return InkWell(
              onTap: () => onSelectDay(day),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.18)
                      : AppTheme.surfaceColor.withValues(
                          alpha: inMonth ? 1 : 0.45,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDropping
                        ? Colors.greenAccent.withValues(alpha: 0.7)
                        : isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.06),
                    width: isDropping ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: inMonth
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (isToday)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    _Badges(scheduled: s, published: p, failed: f),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _firstDayOfGrid(DateTime monthStart) {
    final weekday = monthStart.weekday; // Mon=1..Sun=7
    return monthStart.subtract(Duration(days: weekday - 1));
  }
}

class _Badges extends StatelessWidget {
  final int scheduled;
  final int published;
  final int failed;

  const _Badges({
    required this.scheduled,
    required this.published,
    required this.failed,
  });

  Widget _badge(int count, Color color) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _badge(scheduled, Colors.orange),
        _badge(published, Colors.green),
        _badge(failed, Colors.redAccent),
      ],
    );
  }
}
