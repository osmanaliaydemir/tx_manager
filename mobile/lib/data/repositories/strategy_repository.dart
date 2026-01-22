import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_manager_mobile/core/network/api_dio.dart';
import 'package:tx_manager_mobile/domain/entities/strategy.dart';

// Provider Definition
final strategyRepositoryProvider = Provider((ref) => StrategyRepository());

class StrategyRepository {
  final Dio _dio = createApiDio();

  Future<void> saveStrategy(UserStrategy strategy) async {
    // Convert Enums to Indexes or Strings matching Backend
    // Backend expects Int for Enum (0,1,2..) usually if default JSON serialization
    final data = {
      'PrimaryGoal': strategy.primaryGoal.index,
      'Tone': strategy.tone.index,
      'ForbiddenTopics': strategy.forbiddenTopics,
      'Language': strategy.language,
    };

    try {
      await _dio.post('/api/strategy', data: data);
    } catch (e) {
      throw Exception("Failed to save strategy: $e");
    }
  }
}
