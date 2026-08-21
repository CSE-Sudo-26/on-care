class ClientExerciseWeek {
  const ClientExerciseWeek({
    required this.dayLabels,
    required this.dailyMinutes,
    required this.dailyCalories,
    required this.totalMinutes,
    required this.totalCalories,
    this.cardioMinutes = const <int>[],
    this.strengthMinutes = const <int>[],
    this.stretchingMinutes = const <int>[],
    this.otherMinutes = const <int>[],
    this.strengthSets = const <int>[],
    this.sessionCount,
    this.weeklyGoalMinutes = 0,
  });

  final List<String> dayLabels;
  final List<int> dailyMinutes;
  final List<int> dailyCalories;

  /// 요일별 유형 분해(월→일). 서버가 `/exercise-week` 에서 늘 함께 내려주는데
  /// 예전에는 앱이 읽지 않아, 60분이 무엇으로 채워졌는지 트레이너가 알 수
  /// 없었다(#943). 셋의 합은 [dailyMinutes] 와 같다.
  final List<int> cardioMinutes;
  final List<int> strengthMinutes;
  final List<int> stretchingMinutes;

  /// 목표가 없는 나머지 운동(기타). 그래프에는 그리지 않고 분 수만 적는다 —
  /// 무엇에 견줘야 할지 정해지지 않은 값을 막대로 쌓으면 다른 유형의 높이까지
  /// 뜻을 잃는다. 회원 앱과 같은 규칙이다.
  final List<int> otherMinutes;

  /// 요일별 **근력 세트 수**. 근력은 시간이 아니라 세트로 재는 운동이라, 서버가
  /// 기록한 값을 그대로 내려준다. 비어 있으면 분에서 환산한다.
  final List<int> strengthSets;

  final int totalMinutes;
  final int totalCalories;
  final int? sessionCount;

  /// 이 회원의 주간 운동 시간 목표(분). 그래프의 목표선이 회원 앱과 같은 값을
  /// 쓰게 서버가 함께 내려준다 — 트레이너 화면은 회원 프로필을 따로 읽지
  /// 않는다. (#1015)
  final int weeklyGoalMinutes;

  /// 유형 분해가 실려 왔는가. 길이가 어긋난 응답은 없는 것으로 본다 — 반쪽만
  /// 쌓으면 막대가 실제보다 낮아 보인다.
  bool get hasTypeSplit {
    final int n = dailyMinutes.length;
    return n > 0 &&
        cardioMinutes.length == n &&
        strengthMinutes.length == n &&
        stretchingMinutes.length == n;
  }

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
      cardioMinutes: ints('cardio_minutes'),
      strengthMinutes: ints('strength_minutes'),
      stretchingMinutes: ints('stretching_minutes'),
      otherMinutes: ints('other_minutes'),
      strengthSets: ints('strength_sets'),
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessions'] as List<Object?>?)?.length,
      weeklyGoalMinutes: (json['weekly_goal_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}
