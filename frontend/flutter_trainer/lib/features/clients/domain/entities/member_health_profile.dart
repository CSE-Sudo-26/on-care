class MemberHealthProfile {
  const MemberHealthProfile({
    required this.memberId,
    required this.memberName,
    this.heightCm,
    this.weightKg,
    this.gender = '',
    this.conditions = '',
    this.goals = '',
    this.dailyCalories,
    this.dailySodiumMg,
    this.weeklyWorkoutGoal,
    this.weeklyExerciseMinutesGoal,
    this.weeklyBurnGoal,
  });

  final String memberId;
  final String memberName;
  final double? heightCm;
  final double? weightKg;
  final String gender;
  final String conditions;
  final String goals;
  final int? dailyCalories;
  final int? dailySodiumMg;
  final int? weeklyWorkoutGoal;
  final int? weeklyExerciseMinutesGoal;
  final int? weeklyBurnGoal;

  factory MemberHealthProfile.fromJson(Map<String, Object?> json) =>
      MemberHealthProfile(
        memberId: json['member_id'] as String? ?? '',
        memberName: json['member_name'] as String? ?? '',
        heightCm: (json['height_cm'] as num?)?.toDouble(),
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        gender: json['gender'] as String? ?? '',
        conditions: json['conditions'] as String? ?? '',
        goals: json['goals'] as String? ?? '',
        dailyCalories: (json['daily_calories'] as num?)?.toInt(),
        dailySodiumMg: (json['daily_sodium_mg'] as num?)?.toInt(),
        weeklyWorkoutGoal: (json['weekly_workout_goal'] as num?)?.toInt(),
        weeklyExerciseMinutesGoal:
            (json['weekly_exercise_minutes_goal'] as num?)?.toInt(),
        weeklyBurnGoal: (json['weekly_burn_goal'] as num?)?.toInt(),
      );
}
