class ClientExerciseWeek {
  const ClientExerciseWeek({
    required this.dayLabels,
    required this.dailyMinutes,
    required this.dailyCalories,
    required this.totalMinutes,
    required this.totalCalories,
    this.sessionCount,
  });

  final List<String> dayLabels;
  final List<int> dailyMinutes;
  final List<int> dailyCalories;
  final int totalMinutes;
  final int totalCalories;
  final int? sessionCount;

  int get workoutCount =>
      sessionCount ?? dailyMinutes.where((minutes) => minutes > 0).length;

  factory ClientExerciseWeek.fromJson(Map<String, Object?> json) {
    List<int> ints(String key) =>
        ((json[key] as List<Object?>?) ?? const <Object?>[])
            .map((value) => (value! as num).toInt())
            .toList(growable: false);

    return ClientExerciseWeek(
      dayLabels: ((json['day_labels'] as List<Object?>?) ?? const <Object?>[])
          .cast<String>()
          .toList(growable: false),
      dailyMinutes: ints('daily_minutes'),
      dailyCalories: ints('daily_calories'),
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessions'] as List<Object?>?)?.length,
    );
  }
}
