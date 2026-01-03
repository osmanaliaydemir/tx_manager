import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tx_manager_mobile/core/constants/api_constants.dart';
import 'package:tx_manager_mobile/domain/entities/strategy.dart';

// Provider Definition
final strategyRepositoryProvider = Provider((ref) => StrategyRepository());

class StrategyRepository {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveStrategy(UserStrategy strategy) async {
    final userId = await _storage.read(key: 'auth_token');

    // Convert Enums to Indexes or Strings matching Backend
    // Backend expects Int for Enum (0,1,2..) usually if default JSON serialization
    final data = {
      'PrimaryGoal': strategy.primaryGoal.index,
      'Tone': strategy.tone.index,
      'ForbiddenTopics': strategy.forbiddenTopics,
      'Language': strategy.language,
    };

    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/api/strategy/$userId',
        data: data,
      );
    } catch (e) {
      throw Exception("Failed to save strategy: $e");
    }
  }
}
