import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/analytics_repository.dart';
import 'package:tx_manager_mobile/domain/entities/analytics.dart';

class _AnalyticsBundle {
  final AnalyticsSummary summary;
  final AnalyticsTimeseries timeseries;
  final AnalyticsTopPosts top;

  _AnalyticsBundle(this.summary, this.timeseries, this.top);
}

final analyticsBundleProvider = FutureProvider<_AnalyticsBundle>((ref) async {
  final repo = ref.read(analyticsRepositoryProvider);
  final summary = await repo.getSummary(days: 30);
  final ts = await repo.getTimeseries(days: 30);
  final top = await repo.getTop(days: 30, take: 10, sortBy: 'impressions');
  return _AnalyticsBundle(summary, ts, top);
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
        gradient: const LinearGradient(
          colors: [AppTheme.cardGradientStart, AppTheme.cardGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (accent ?? AppTheme.primaryColor).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent ?? AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(analyticsBundleProvider);
    final dateFmt = DateFormat('dd MMM');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Analiz'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(analyticsBundleProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Hata: $e',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (bundle) {
          final s = bundle.summary;
          final ts = bundle.timeseries.points;
          final top = bundle.top.items;

          final lastUpdateLocal = s.lastMetricsUpdateUtc?.toLocal();
          final lastUpdateText = lastUpdateLocal == null
              ? '—'
              : DateFormat('dd MMM HH:mm').format(lastUpdateLocal);

          final lastPoints = ts.length <= 14 ? ts : ts.sublist(ts.length - 14);

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async => ref.invalidate(analyticsBundleProvider),
            child: ListView(
              children: [
                _sectionTitle('Genel'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              title: 'Toplam post',
                              value: '${s.totalPosts}',
                              icon: Icons.dynamic_feed,
                              accent: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              title: 'Yayınlanan',
                              value: '${s.publishedCount}',
                              icon: Icons.check_circle,
                              accent: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              title: 'Planlı',
                              value: '${s.scheduledCount}',
                              icon: Icons.schedule,
                              accent: Colors.amberAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              title: 'Başarısız',
                              value: '${s.failedCount}',
                              icon: Icons.error_outline,
                              accent: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Son metrik güncelleme: $lastUpdateText',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
                _sectionTitle('Son ${s.days} gün etkileşim'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              title: 'İzlenim',
                              value: '${s.totalImpressions}',
                              icon: Icons.visibility,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              title: 'Beğeni',
                              value: '${s.totalLikes}',
                              icon: Icons.favorite,
                              accent: AppTheme.accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              title: 'Retweet',
                              value: '${s.totalRetweets}',
                              icon: Icons.repeat,
                              accent: Colors.lightBlueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              title: 'Yanıt',
                              value: '${s.totalReplies}',
                              icon: Icons.forum,
                              accent: Colors.deepPurpleAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ortalama (yayınlanan başına): '
                          '${s.avgImpressionsPerPublished.toStringAsFixed(1)} izlenim, '
                          '${s.avgLikesPerPublished.toStringAsFixed(1)} beğeni',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
                _sectionTitle('Trend (son 14 gün, yayınlananlar)'),
                if (lastPoints.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Henüz trend verisi yok.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.glassBorder),
                        color: AppTheme.surfaceColor,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lastPoints.length,
                        separatorBuilder: (_, _) => Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (context, i) {
                          final p = lastPoints[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              dateFmt.format(p.dateUtc.toLocal()),
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${p.publishedCount} post',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${p.impressions} izlenim',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '${p.likes} beğeni',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                _sectionTitle('Top postlar (izlenim)'),
                if (top.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Henüz top post yok.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.glassBorder),
                        color: AppTheme.surfaceColor,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: top.length,
                        separatorBuilder: (_, _) => Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (context, i) {
                          final p = top[i];
                          return ListTile(
                            title: Text(
                              p.contentPreview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '❤️ ${p.likeCount}  🔁 ${p.retweetCount}  💬 ${p.replyCount}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Text(
                              '${p.impressionCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
