import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/core/offline/outbox.dart';
import 'package:tx_manager_mobile/core/offline/outbox_executor.dart';
import 'package:tx_manager_mobile/data/repositories/post_repository.dart';
import 'package:tx_manager_mobile/data/repositories/suggestion_repository.dart';
import 'package:tx_manager_mobile/presentation/analytics/analytics_screen.dart';
import 'package:tx_manager_mobile/presentation/home/home_screen.dart';
import 'package:tx_manager_mobile/presentation/home/calendar_screen.dart';
import 'package:tx_manager_mobile/presentation/offline/outbox_sheet.dart';
import 'package:tx_manager_mobile/presentation/suggestions/ai_suggestions_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _flushTimer;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const AiSuggestionsScreen(),
    const AnalyticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _flushTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _flushOutbox();
    });

    // initial best-effort flush
    _flushOutbox();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _flushTimer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flushOutbox();
    }
  }

  void _flushOutbox() {
    final processor = ref.read(outboxProcessorProvider);
    final exec = OutboxExecutor(
      posts: ref.read(postRepositoryProvider),
      suggestions: ref.read(suggestionRepositoryProvider),
    );

    processor.flushBestEffort(execute: exec.execute);
  }

  Future<void> _retryOne(String actionId) async {
    final processor = ref.read(outboxProcessorProvider);
    final exec = OutboxExecutor(
      posts: ref.read(postRepositoryProvider),
      suggestions: ref.read(suggestionRepositoryProvider),
    );
    await processor.retryOne(actionId: actionId, execute: exec.execute);
  }

  Widget _outboxBanner(int outboxCount) {
    return Material(
      color: Colors.orange.withValues(alpha: 0.16),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$outboxCount işlem kuyruğa alındı. Bağlantı gelince otomatik denenecek.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => _flushOutbox(),
                child: const Text('Şimdi dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeIcon({required Widget icon, required int count}) {
    if (count <= 0) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final outboxCount = ref
        .watch(outboxCountProvider)
        .maybeWhen(data: (v) => v, orElse: () => 0);

    return Scaffold(
      body: Column(
        children: [
          if (outboxCount > 0) _outboxBanner(outboxCount),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      floatingActionButton: outboxCount <= 0
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.cloud_upload),
              label: Text('Kuyruk ($outboxCount)'),
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => OutboxSheet(
                    onFlushNow: () async {
                      _flushOutbox();
                      // give it a moment; flush is async and best-effort
                      await Future<void>.delayed(
                        const Duration(milliseconds: 200),
                      );
                    },
                    onRetryOne: (id) async {
                      await _retryOne(id);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 200),
                      );
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.black,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(
            icon: _badgeIcon(
              icon: const Icon(Icons.edit_outlined),
              count: outboxCount,
            ),
            selectedIcon: _badgeIcon(
              icon: const Icon(Icons.edit),
              count: outboxCount,
            ),
            label: 'Yaz',
          ),
          NavigationDestination(
            icon: _badgeIcon(
              icon: const Icon(Icons.calendar_month_outlined),
              count: outboxCount,
            ),
            selectedIcon: _badgeIcon(
              icon: const Icon(Icons.calendar_month),
              count: outboxCount,
            ),
            label: 'Planlamalar',
          ),
          NavigationDestination(
            icon: _badgeIcon(
              icon: const Icon(Icons.auto_awesome_outlined),
              count: outboxCount,
            ),
            selectedIcon: _badgeIcon(
              icon: const Icon(Icons.auto_awesome),
              count: outboxCount,
            ),
            label: 'Öneriler',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analiz',
          ),
        ],
      ),
    );
  }
}
