enum ExerciseType { cardio, strength, yoga, walking, stretching, other }

ExerciseType _exerciseTypeFromString(String s) => ExerciseType.values
    .firstWhere((t) => t.name == s, orElse: () => ExerciseType.other);

/// Workout intensity, persisted so the edit sheet reopens at the saved
/// level and calorie estimates stay consistent. Order matches the
/// 가벼움 / 보통 / 높음 chips and the `_intensityFactor` multipliers.
enum ExerciseIntensity { light, moderate, high }

ExerciseIntensity _exerciseIntensityFromString(String? s) =>
    ExerciseIntensity.values.firstWhere(
      (i) => i.name == s,
      orElse: () => ExerciseIntensity.moderate,
    );

class ExerciseSession {
  const ExerciseSession({
    this.id,
    required this.dayLabel,
    required this.type,
    required this.minutes,
    required this.calories,
    this.intensity = ExerciseIntensity.moderate,
    this.dateLabel,
    this.timeLabel,
    this.items = const <String>[],
  });

  final String? id;
  final String dayLabel;
  final ExerciseType type;
  final int minutes;
  final int calories;

  /// Saved workout intensity. Defaults to [ExerciseIntensity.moderate] for
  /// legacy payloads that predate the field.
  final ExerciseIntensity intensity;

  /// Day-of-record label shown above the session card. `오늘`, `어제`,
  /// or `5월 12일`. Optional because older payloads (and the unit
  /// tests) don't carry it — derive a placeholder if absent.
  final String? dateLabel;

  /// Wall-clock label like `14:30`. Optional.
  final String? timeLabel;

  /// Bulleted exercise items, e.g. `['러닝머신 30분', '사이클 15분']`.
  /// Optional; empty for the legacy mock rows.
  final List<String> items;

  factory ExerciseSession.fromJson(Map<String, Object?> json) =>
      ExerciseSession(
        id: json['id'] as String?,
        dayLabel: json['day_label']! as String,
        type: _exerciseTypeFromString(json['type']! as String),
        minutes: (json['minutes']! as num).toInt(),
        calories: (json['calories']! as num).toInt(),
        intensity: _exerciseIntensityFromString(json['intensity'] as String?),
        dateLabel: json['date_label'] as String?,
        timeLabel: json['time_label'] as String?,
        items: ((json['items'] as List<Object?>?) ?? const <Object?>[])
            .cast<String>()
            .toList(),
      );
}

class ExerciseWeek {
  const ExerciseWeek({
    required this.sessions,
    required this.dailyMinutes,
    required this.dayLabels,
    required this.totalMinutes,
    required this.totalCalories,
    required this.streakDays,
    required this.aiCoachMessage,
    this.cardioMinutes = const <double>[],
    this.strengthMinutes = const <double>[],
    this.stretchingMinutes = const <double>[],
  });

  final List<ExerciseSession> sessions;
  final List<double> dailyMinutes;
  final List<String> dayLabels;
  final int totalMinutes;
  final int totalCalories;
  final int streakDays;
  final String aiCoachMessage;

  /// Per-day minutes broken out by type for the stacked weekly chart.
  /// All three lists are the same length as [dailyMinutes] when the
  /// payload includes them; otherwise empty and the chart falls back
  /// to a single-series view.
  final List<double> cardioMinutes;
  final List<double> strengthMinutes;
  final List<double> stretchingMinutes;

  /// Count of distinct days on which the user worked out, matching
  /// the prototype's "이번 주 N회" tile semantics. Multiple sessions
  /// on the same day collapse to one.
  int get workoutCount => sessions.map((s) => s.dayLabel).toSet().length;

  factory ExerciseWeek.fromJson(Map<String, Object?> json) {
    List<double> parseDoubleList(String key) {
      final raw = json[key] as List<Object?>?;
      if (raw == null) return const <double>[];
      return raw.map((v) => (v! as num).toDouble()).toList();
    }

    return ExerciseWeek(
      sessions: (json['sessions']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(ExerciseSession.fromJson)
          .toList(),
      dailyMinutes: parseDoubleList('daily_minutes'),
      dayLabels: (json['day_labels']! as List<Object?>).cast<String>().toList(),
      totalMinutes: (json['total_minutes']! as num).toInt(),
      totalCalories: (json['total_calories']! as num).toInt(),
      streakDays: (json['streak_days']! as num).toInt(),
      aiCoachMessage: json['ai_coach_message']! as String,
      cardioMinutes: parseDoubleList('cardio_minutes'),
      strengthMinutes: parseDoubleList('strength_minutes'),
      stretchingMinutes: parseDoubleList('stretching_minutes'),
    );
  }
}
