import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/core/network/api_dio.dart';
import 'package:tx_manager_mobile/domain/entities/analytics.dart';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

class AnalyticsRepository {
  final Dio _dio = createApiDio();

  Future<AnalyticsSummary> getSummary({int days = 30}) async {
    final res = await _dio.get(
      '/api/analytics/summary',
      queryParameters: {'days': days},
    );
    return AnalyticsSummary.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<AnalyticsTimeseries> getTimeseries({int days = 30}) async {
    final res = await _dio.get(
      '/api/analytics/timeseries',
      queryParameters: {'days': days},
    );
    return AnalyticsTimeseries.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<AnalyticsTopPosts> getTop({
    int days = 30,
    int take = 10,
    String sortBy = 'impressions',
  }) async {
    final res = await _dio.get(
      '/api/analytics/top',
      queryParameters: {'days': days, 'take': take, 'sortBy': sortBy},
    );
    return AnalyticsTopPosts.fromJson(Map<String, dynamic>.from(res.data));
  }
}
