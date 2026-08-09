import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/domain/repositories/account_repository.dart';

/// Not wired by default (the app uses [DioAccountRepository] → the drift-backed
/// LocalApiInterceptor). Kept for unit tests / offline overrides.
class MockAccountRepository implements AccountRepository {
  MockAccountRepository();

  UserProfile _profile = const UserProfile(
    id: 'user-demo',
    name: '김민수',
    email: 'minsu@oncare.com',
    phone: '010-1234-5678',
    birthDate: '1990-01-15',
    dailyCalories: 2000,
    dailySodiumMg: 2000,
    dailySugarG: 50,
    dailyCarbsG: 275,
    dailyProteinG: 100,
    dailyFatG: 55,
  );

  @override
  Future<UserProfile> fetchProfile() async => _profile;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<UserProfile> submitOnboarding({
    String? birthDate,
    String? gender,
    num? heightCm,
    String? conditions,
    int? dailySodiumMg,
  }) async => _profile;

  @override
  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? birthDate,
  }) async => _profile;

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
    _profile = UserProfile(
      id: _profile.id,
      name: _profile.name,
      email: _profile.email,
      phone: _profile.phone,
      birthDate: _profile.birthDate,
      dailyCalories: dailyCalories ?? _profile.dailyCalories,
      dailySodiumMg: dailySodiumMg ?? _profile.dailySodiumMg,
      dailySugarG: dailySugarG ?? _profile.dailySugarG,
      dailyCarbsG: dailyCarbsG ?? _profile.dailyCarbsG,
      dailyProteinG: dailyProteinG ?? _profile.dailyProteinG,
      dailyFatG: dailyFatG ?? _profile.dailyFatG,
      weeklyWorkoutGoal: weeklyWorkoutGoal ?? _profile.weeklyWorkoutGoal,
      weeklyExerciseMinutesGoal:
          weeklyExerciseMinutesGoal ?? _profile.weeklyExerciseMinutesGoal,
      weeklyBurnGoal: weeklyBurnGoal ?? _profile.weeklyBurnGoal,
    );
    return _profile;
  }
}
