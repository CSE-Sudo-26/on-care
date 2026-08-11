import 'package:oncare/features/account/domain/entities/user_profile.dart';

abstract class AccountRepository {
  Future<UserProfile> fetchProfile();

  /// DELETE /users/me — withdraw the account. The server cascade-deletes
  /// the profile, diet/exercise, schedule, notifications and linked
  /// social accounts.
  Future<void> deleteAccount();

  /// PUT /users/me/health-goals — 건강 목표(식단 일일 6종 + 주간 운동 3종).
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
  });

  /// POST /users/me/onboarding — first-run setup. All fields optional
  /// (partial save allowed); the backend marks the profile onboarded.
  Future<UserProfile> submitOnboarding({
    String? birthDate,
    String? gender,
    num? heightCm,
    num? weightKg,
    String? conditions,
    int? dailySodiumMg,
  });

  /// PUT /users/me — update basic profile (name/email/phone/birth).
  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? birthDate,
    String? gender,
    num? heightCm,
    num? weightKg,
    String? goals,
  });
}
