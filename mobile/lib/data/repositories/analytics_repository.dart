import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/domain/entities/analytics.dart';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

class AnalyticsRepository {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<AnalyticsSummary> getSummary({int days = 30}) async {
    final headers = await _authHeaders();
    final res = await _dio.get(
      '${ApiConstants.baseUrl}/api/analytics/summary',
      options: Options(headers: headers),
      queryParameters: {'days': days},
    );
    return AnalyticsSummary.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<AnalyticsTimeseries> getTimeseries({int days = 30}) async {
    final headers = await _authHeaders();
    final res = await _dio.get(
      '${ApiConstants.baseUrl}/api/analytics/timeseries',
      options: Options(headers: headers),
      queryParameters: {'days': days},
    );
    return AnalyticsTimeseries.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<AnalyticsTopPosts> getTop({
    int days = 30,
    int take = 10,
    String sortBy = 'impressions',
  }) async {
    final headers = await _authHeaders();
    final res = await _dio.get(
      '${ApiConstants.baseUrl}/api/analytics/top',
      options: Options(headers: headers),
      queryParameters: {'days': days, 'take': take, 'sortBy': sortBy},
    );
    return AnalyticsTopPosts.fromJson(Map<String, dynamic>.from(res.data));
  }
}
