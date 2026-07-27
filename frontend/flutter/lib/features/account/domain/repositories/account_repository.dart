import 'package:oncare/features/account/domain/entities/user_profile.dart';

abstract class AccountRepository {
  Future<UserProfile> fetchProfile();

  /// DELETE /users/me — withdraw the account. The server cascade-deletes
  /// the profile, diet/exercise/vitals, schedule, notifications and
  /// linked social accounts.
  Future<void> deleteAccount();

  /// POST /users/me/onboarding — first-run setup. All fields optional
  /// (partial save allowed); the backend marks the profile onboarded.
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
  });

  /// PUT /users/me — update basic profile (name/email/phone/birth).
  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? birthDate,
  });

  /// PUT /users/me/health-goals — update goal targets.
  Future<UserProfile> updateHealthGoals({
    num? goalWeightKg,
    int? goalBpSystolic,
    int? goalBloodSugar,
    int? dailyCalories,
    int? dailySodiumMg,
    int? dailySugarG,
  });
}
