import 'package:oncare/features/account/domain/entities/goal_update.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/domain/repositories/account_repository.dart';

/// Not wired by default (the app uses [DioAccountRepository] → the drift-backed
/// LocalApiInterceptor). Kept for unit tests / offline overrides.
class MockAccountRepository implements AccountRepository {
  MockAccountRepository({UserProfile profile = _demo}) : _profile = profile;

  static const UserProfile _demo = UserProfile(
    id: 'user-demo',
    name: '김민수',
    email: 'minsu@oncare.com',
    phone: '010-1234-5678',
    birthDate: '1990-01-15',
    // 트레이너 앱의 김민수와 같은 사람이다 — 성별과 목표가 두 앱에서 같아야
    // 한다 (#1140).
    gender: 'male',
    goals: '혈압 관리 · 체중 감량',
    dailyCalories: 2000,
    dailySodiumMg: 2000,
    dailySugarG: 50,
    dailyCarbsG: 275,
    dailyProteinG: 100,
    dailyFatG: 55,
    weeklyWorkoutGoal: UserProfile.defaultWeeklyWorkoutGoal,
    weeklyExerciseMinutesGoal: UserProfile.defaultWeeklyExerciseMinutesGoal,
    weeklyBurnGoal: UserProfile.defaultWeeklyBurnGoal,
  );

  UserProfile _profile;

  @override
  Future<UserProfile> fetchProfile() async => _profile;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<UserProfile> submitOnboarding({
    String? birthDate,
    String? gender,
    num? heightCm,
    num? weightKg,
    String? conditions,
    String? goals,
    int? dailySodiumMg,
  }) async {
    _profile = _replaceProfile(
      birthDate: birthDate,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      goals: goals,
      dailySodiumMg: dailySodiumMg,
    );
    return _profile;
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
    _profile = _replaceProfile(
      name: name,
      email: email,
      phone: phone,
      birthDate: birthDate,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      goals: goals,
    );
    return _profile;
  }

  UserProfile _replaceProfile({
    String? name,
    String? email,
    String? phone,
    String? birthDate,
    String? gender,
    num? heightCm,
    num? weightKg,
    String? goals,
    int? dailySodiumMg,
  }) => UserProfile(
    id: _profile.id,
    name: name ?? _profile.name,
    email: email ?? _profile.email,
    phone: phone ?? _profile.phone,
    birthDate: birthDate ?? _profile.birthDate,
    gender: gender ?? _profile.gender,
    heightCm: heightCm?.toDouble() ?? _profile.heightCm,
    weightKg: weightKg?.toDouble() ?? _profile.weightKg,
    goals: goals ?? _profile.goals,
    dailyCalories: _profile.dailyCalories,
    dailySodiumMg: dailySodiumMg ?? _profile.dailySodiumMg,
    dailySugarG: _profile.dailySugarG,
    dailyCarbsG: _profile.dailyCarbsG,
    dailyProteinG: _profile.dailyProteinG,
    dailyFatG: _profile.dailyFatG,
    weeklyWorkoutGoal: _profile.weeklyWorkoutGoal,
    weeklyExerciseMinutesGoal: _profile.weeklyExerciseMinutesGoal,
    weeklyBurnGoal: _profile.weeklyBurnGoal,
  );

  @override
  Future<UserProfile> updateHealthGoals({
    GoalUpdate? dailyCalories,
    GoalUpdate? dailySodiumMg,
    GoalUpdate? dailySugarG,
    GoalUpdate? dailyCarbsG,
    GoalUpdate? dailyProteinG,
    GoalUpdate? dailyFatG,
    GoalUpdate? weeklyWorkoutGoal,
    GoalUpdate? weeklyExerciseMinutesGoal,
    GoalUpdate? weeklyBurnGoal,
    GoalUpdate? dailyBurnKcal,
    GoalUpdate? weeklyCardioMinutes,
    GoalUpdate? weeklyStrengthSets,
    GoalUpdate? weeklyFlexibilityMinutes,
  }) async {
    _profile = UserProfile(
      id: _profile.id,
      name: _profile.name,
      email: _profile.email,
      phone: _profile.phone,
      birthDate: _profile.birthDate,
      gender: _profile.gender,
      heightCm: _profile.heightCm,
      weightKg: _profile.weightKg,
      goals: _profile.goals,
      dailyCalories: dailyCalories == null
          ? _profile.dailyCalories
          : dailyCalories.value,
      dailySodiumMg: dailySodiumMg == null
          ? _profile.dailySodiumMg
          : dailySodiumMg.value,
      dailySugarG: dailySugarG == null
          ? _profile.dailySugarG
          : dailySugarG.value,
      dailyCarbsG: dailyCarbsG == null
          ? _profile.dailyCarbsG
          : dailyCarbsG.value,
      dailyProteinG: dailyProteinG == null
          ? _profile.dailyProteinG
          : dailyProteinG.value,
      dailyFatG: dailyFatG == null ? _profile.dailyFatG : dailyFatG.value,
      weeklyWorkoutGoal: weeklyWorkoutGoal == null
          ? _profile.weeklyWorkoutGoal
          : weeklyWorkoutGoal.value,
      weeklyExerciseMinutesGoal: weeklyExerciseMinutesGoal == null
          ? _profile.weeklyExerciseMinutesGoal
          : weeklyExerciseMinutesGoal.value,
      weeklyBurnGoal: weeklyBurnGoal == null
          ? _profile.weeklyBurnGoal
          : weeklyBurnGoal.value,
      dailyBurnKcal: dailyBurnKcal == null
          ? _profile.dailyBurnKcal
          : dailyBurnKcal.value,
      weeklyCardioMinutes: weeklyCardioMinutes == null
          ? _profile.weeklyCardioMinutes
          : weeklyCardioMinutes.value,
      weeklyStrengthSets: weeklyStrengthSets == null
          ? _profile.weeklyStrengthSets
          : weeklyStrengthSets.value,
      weeklyFlexibilityMinutes: weeklyFlexibilityMinutes == null
          ? _profile.weeklyFlexibilityMinutes
          : weeklyFlexibilityMinutes.value,
    );
    return _profile;
  }
}
