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
    String? gender,
    num? heightCm,
    num? weightKg,
    String? goals,
  }) async {
    final res = await _dio.put<Map<String, Object?>>(
      '/users/me',
      data: <String, Object?>{
        'name': ?name,
        'email': ?email,
        'phone': ?phone,
        'birth_date': ?birthDate,
        'gender': ?gender,
        'height_cm': ?heightCm,
        'weight_kg': ?weightKg,
        'goals': ?goals,
      },
    );
    return UserProfile.fromJson(res.data!);
  }

  @override
  Future<UserProfile> updateHealthGoals({
    int? dailyCalories,
    int? dailySodiumMg,
    int? dailySugarG,
    int? dailyCarbsG,
    int? dailyProteinG,
    int? dailyFatG,
    int? weeklyWorkoutGoal,
    int? weeklyExerciseMinutesGoal,
    int? weeklyBurnGoal,
  }) async {
    final res = await _dio.put<Map<String, Object?>>(
      '/users/me/health-goals',
      data: <String, Object?>{
        'daily_calories': ?dailyCalories,
        'daily_sodium_mg': ?dailySodiumMg,
        'daily_sugar_g': ?dailySugarG,
        'daily_carbs_g': ?dailyCarbsG,
        'daily_protein_g': ?dailyProteinG,
        'daily_fat_g': ?dailyFatG,
        'weekly_workout_goal': ?weeklyWorkoutGoal,
        'weekly_exercise_minutes_goal': ?weeklyExerciseMinutesGoal,
        'weekly_burn_goal': ?weeklyBurnGoal,
      },
    );
    return UserProfile.fromJson(res.data!);
  }
}
