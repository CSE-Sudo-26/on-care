import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/domain/repositories/account_repository.dart';

/// Not wired by default (the app uses [DioAccountRepository] → the drift-backed
/// LocalApiInterceptor). Kept for unit tests / offline overrides.
class MockAccountRepository implements AccountRepository {
  const MockAccountRepository();

  static const UserProfile _demo = UserProfile(
    id: 'user-demo',
    name: '김민수',
    email: 'minsu@oncare.com',
    phone: '010-1234-5678',
    birthDate: '1990-01-15',
    goalWeightKg: 70,
    goalBpSystolic: 120,
    goalBloodSugar: 100,
    dailyCalories: 2000,
    dailySodiumMg: 2000,
    dailySugarG: 50,
  );

  @override
  Future<UserProfile> fetchProfile() async => _demo;

  @override
  Future<void> deleteAccount() async {}

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
  }) async => _demo;

  @override
  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? birthDate,
  }) async => _demo;

  @override
  Future<UserProfile> updateHealthGoals({
    num? goalWeightKg,
    int? goalBpSystolic,
    int? goalBloodSugar,
    int? dailyCalories,
    int? dailySodiumMg,
    int? dailySugarG,
  }) async => _demo;
}
