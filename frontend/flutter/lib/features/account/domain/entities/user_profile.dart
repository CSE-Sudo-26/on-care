/// GET /users/me/profile — the consolidated profile the settings modals
/// edit (내 프로필 + 건강 목표).
class UserProfile {
  static const int defaultDailyCalories = 2000;
  static const int defaultDailySodiumMg = 2000;
  static const int defaultDailySugarG = 50;
  static const int defaultDailyCarbsG = 275;
  static const int defaultDailyProteinG = 100;
  static const int defaultDailyFatG = 55;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.birthDate = '',
    this.gender = '',
    this.heightCm,
    this.weightKg,
    this.goals = '',
    this.dailyCalories,
    this.dailySodiumMg,
    this.dailySugarG,
    this.dailyCarbsG,
    this.dailyProteinG,
    this.dailyFatG,
    this.weeklyWorkoutGoal,
    this.weeklyExerciseMinutesGoal,
    this.weeklyBurnGoal,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String birthDate;
  final String gender;
  final double? heightCm;
  final double? weightKg;
  final String goals;

  // 식단 일일 목표 — 홈 영양 현황의 목표치와 같은 값을 공유한다.
  final int? dailyCalories;
  final int? dailySodiumMg;
  final int? dailySugarG;
  final int? dailyCarbsG;
  final int? dailyProteinG;
  final int? dailyFatG;

  int get effectiveDailyCalories => dailyCalories ?? defaultDailyCalories;
  int get effectiveDailySodiumMg => dailySodiumMg ?? defaultDailySodiumMg;
  int get effectiveDailySugarG => dailySugarG ?? defaultDailySugarG;
  int get effectiveDailyCarbsG => dailyCarbsG ?? defaultDailyCarbsG;
  int get effectiveDailyProteinG => dailyProteinG ?? defaultDailyProteinG;
  int get effectiveDailyFatG => dailyFatG ?? defaultDailyFatG;

  // 주간 운동 목표.
  final int? weeklyWorkoutGoal; // 횟수
  final int? weeklyExerciseMinutesGoal; // 분
  final int? weeklyBurnGoal; // kcal

  static const int defaultWeeklyWorkoutGoal = 3;
  static const int defaultWeeklyExerciseMinutesGoal = 150;
  static const int defaultWeeklyBurnGoal = 500;

  int get effectiveWeeklyWorkoutGoal =>
      weeklyWorkoutGoal ?? defaultWeeklyWorkoutGoal;
  int get effectiveWeeklyExerciseMinutesGoal =>
      weeklyExerciseMinutesGoal ?? defaultWeeklyExerciseMinutesGoal;
  int get effectiveWeeklyBurnGoal => weeklyBurnGoal ?? defaultWeeklyBurnGoal;

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    birthDate: (json['birth_date'] as String?) ?? '',
    gender: (json['gender'] as String?) ?? '',
    heightCm: (json['height_cm'] as num?)?.toDouble(),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    goals: (json['goals'] as String?) ?? '',
    dailyCalories: (json['daily_calories'] as num?)?.toInt(),
    dailySodiumMg: (json['daily_sodium_mg'] as num?)?.toInt(),
    dailySugarG: (json['daily_sugar_g'] as num?)?.toInt(),
    dailyCarbsG: (json['daily_carbs_g'] as num?)?.toInt(),
    dailyProteinG: (json['daily_protein_g'] as num?)?.toInt(),
    dailyFatG: (json['daily_fat_g'] as num?)?.toInt(),
    weeklyWorkoutGoal: (json['weekly_workout_goal'] as num?)?.toInt(),
    weeklyExerciseMinutesGoal: (json['weekly_exercise_minutes_goal'] as num?)
        ?.toInt(),
    weeklyBurnGoal: (json['weekly_burn_goal'] as num?)?.toInt(),
  );
}
