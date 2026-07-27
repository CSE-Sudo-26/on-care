import 'package:dio/dio.dart';

import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/domain/repositories/account_repository.dart';

class DioAccountRepository implements AccountRepository {
  DioAccountRepository(this._dio);
  final Dio _dio;

  @override
  Future<UserProfile> fetchProfile() async {
    final res = await _dio.get<Map<String, Object?>>('/users/me/profile');
    return UserProfile.fromJson(res.data!);
  }

  @override
  Future<void> deleteAccount() async {
    await _dio.delete<Map<String, Object?>>('/users/me');
  }

  @override
  Future<UserProfile> submitOnboarding({
    String? birthDate,
    String? gender,
    num? heightCm,
    num? weightKg,
    String? conditions,
    num? goalWeightKg,
    int? goalBpSystolic,
    int? goalBloodSugar,
    int? dailySodiumMg,
  }) async {
    final res = await _dio.post<Map<String, Object?>>(
      '/users/me/onboarding',
      data: <String, Object?>{
        'birth_date': ?birthDate,
        'gender': ?gender,
        'height_cm': ?heightCm,
        'weight_kg': ?weightKg,
        'conditions': ?conditions,
        'goal_weight_kg': ?goalWeightKg,
        'goal_bp_systolic': ?goalBpSystolic,
        'goal_blood_sugar': ?goalBloodSugar,
        'daily_sodium_mg': ?dailySodiumMg,
      },
    );
    return UserProfile.fromJson(res.data!);
  }

  @override
  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? birthDate,
  }) async {
    final res = await _dio.put<Map<String, Object?>>(
      '/users/me',
      data: <String, Object?>{
        'name': ?name,
        'email': ?email,
        'phone': ?phone,
        'birth_date': ?birthDate,
      },
    );
    return UserProfile.fromJson(res.data!);
  }

  @override
  Future<UserProfile> updateHealthGoals({
    num? goalWeightKg,
    int? goalBpSystolic,
    int? goalBloodSugar,
    int? dailyCalories,
    int? dailySodiumMg,
    int? dailySugarG,
  }) async {
    final res = await _dio.put<Map<String, Object?>>(
      '/users/me/health-goals',
      data: <String, Object?>{
        'goal_weight_kg': ?goalWeightKg,
        'goal_bp_systolic': ?goalBpSystolic,
        'goal_blood_sugar': ?goalBloodSugar,
        'daily_calories': ?dailyCalories,
        'daily_sodium_mg': ?dailySodiumMg,
        'daily_sugar_g': ?dailySugarG,
      },
    );
    return UserProfile.fromJson(res.data!);
  }
}
