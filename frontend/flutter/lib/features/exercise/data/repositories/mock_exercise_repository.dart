import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';

/// In-memory stateful mock for demo mode (`useMockApi`). Seeds the
/// "상황 1: 오늘 PT 받은 날" scenario, then keeps add/update/delete in memory
/// for the app session so the weekly summary·chart·count reflect edits made
/// through the app (issue #294). A single instance is created by
/// [exerciseRepositoryProvider] and lives for the session, so the drift
/// persists until the app is restarted.
///
/// [_sessions] is the single source of truth: the per-day totals, the
/// stacked-chart series (유산소/근력/스트레칭), and the weekly totals are all
/// derived from it in [_buildWeek]. This keeps the invariant
/// `daily == cardio + strength + stretching` true for every day even after a
/// seed session is edited or deleted — previously the chart arrays were seeded
/// independently of the sessions, so deleting a session left orphaned minutes
/// in a type bucket (리뷰 지적, #294).
class MockExerciseRepository implements ExerciseRepository {
  MockExerciseRepository();

  static const List<String> _dayLabels = <String>[
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];
  static const String _aiCoachMessage =
      '12회차 PT 완료! 코치님이 강조하신 어깨 회전근개 스트레칭과 마무리 유산소로 완벽히 정리해보세요.';

  // 오늘 PT 시나리오 시드. 목·금·토·일 4일 연속 운동 → "4일 연속"과 일치.
  final List<ExerciseSession> _sessions = <ExerciseSession>[
    const ExerciseSession(
      id: 's-mon',
      dateLabel: '월요일',
      dayLabel: '월',
      type: ExerciseType.cardio,
      minutes: 40,
      calories: 300,
    ),
    const ExerciseSession(
      id: 's-tue',
      dateLabel: '화요일',
      dayLabel: '화',
      type: ExerciseType.strength,
      minutes: 60,
      calories: 420,
    ),
    const ExerciseSession(
      id: 's-thu',
      dateLabel: '목요일',
      dayLabel: '목',
      type: ExerciseType.cardio,
      minutes: 65,
      calories: 480,
    ),
    const ExerciseSession(
      id: 's-fri',
      dateLabel: '금요일',
      dayLabel: '금',
      type: ExerciseType.cardio,
      minutes: 55,
      calories: 400,
    ),
    const ExerciseSession(
      id: 's-sat',
      dateLabel: '토요일',
      dayLabel: '토',
      type: ExerciseType.cardio,
      minutes: 45,
      calories: 330,
    ),
    const ExerciseSession(
      id: 's-today',
      dateLabel: '오늘',
      timeLabel: '18:00',
      dayLabel: '일',
      type: ExerciseType.strength,
      minutes: 50,
      calories: 520,
      items: <String>['벤치프레스 40kg 4세트', '덤벨 숄더프레스 10kg 4세트'],
    ),
  ];

  int _seq = 0;

  // 주간 소모 칼로리 헤드라인. 유형별 분(minute) 배열과 달리 칼로리는 유형 분해가
  // 없어, 튜닝된 시나리오 값(1,980kcal)을 CRUD 델타로 유지한다(요약 카드 계약).
  int _totalCalories = 1980;

  @override
  Future<ExerciseWeek> fetchThisWeek() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _buildWeek();
  }

  @override
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final session = ExerciseSession(
      id: 'mock-ex-${++_seq}',
      dayLabel: dayLabel,
      type: type,
      minutes: minutes,
      calories: calories,
      intensity: intensity,
      dateLabel: '오늘',
    );
    _sessions.add(session);
    _totalCalories += calories;
    return session;
  }

  @override
  Future<void> deleteSession(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final int idx = _sessions.indexWhere((ExerciseSession s) => s.id == id);
    if (idx < 0) return;
    _totalCalories = _nonNeg(_totalCalories - _sessions[idx].calories);
    _sessions.removeAt(idx);
  }

  @override
  Future<ExerciseSession> updateSession({
    required String id,
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final int idx = _sessions.indexWhere((ExerciseSession s) => s.id == id);
    final ExerciseSession? old = idx >= 0 ? _sessions[idx] : null;
    final ExerciseSession updated = ExerciseSession(
      id: id,
      dayLabel: dayLabel,
      type: type,
      minutes: minutes,
      calories: calories,
      intensity: intensity,
      dateLabel: old?.dateLabel ?? '오늘',
      timeLabel: old?.timeLabel,
      items: old?.items ?? const <String>[],
    );
    if (idx >= 0 && old != null) {
      _totalCalories = _nonNeg(_totalCalories - old.calories + calories);
      _sessions[idx] = updated;
    }
    return updated;
  }

  // ── 세션에서 파생 ────────────────────────────────────────────────

  /// 요일별/유형별 시간·총분·연속일을 [_sessions]에서 계산한다. daily 는 그 날
  /// 모든 세션 시간의 합이고, 유형별 버킷 합도 같은 세션에서 나오므로
  /// `daily[i] == cardio[i] + strength[i] + stretching[i]` 가 항상 성립한다.
  /// 칼로리만 유형 분해가 없어 튜닝된 [_totalCalories] 헤드라인을 그대로 쓴다.
  ExerciseWeek _buildWeek() {
    final int n = _dayLabels.length;
    final List<double> daily = List<double>.filled(n, 0);
    final List<double> cardio = List<double>.filled(n, 0);
    final List<double> strength = List<double>.filled(n, 0);
    final List<double> stretching = List<double>.filled(n, 0);
    int totalMinutes = 0;

    for (final ExerciseSession s in _sessions) {
      final int i = _dayLabels.indexOf(s.dayLabel);
      if (i >= 0) {
        daily[i] += s.minutes;
        _bucketFor(s.type, cardio, strength, stretching)[i] += s.minutes;
      }
      totalMinutes += s.minutes;
    }

    return ExerciseWeek(
      dailyMinutes: daily,
      cardioMinutes: cardio,
      strengthMinutes: strength,
      stretchingMinutes: stretching,
      dayLabels: List<String>.of(_dayLabels),
      totalMinutes: totalMinutes,
      totalCalories: _totalCalories,
      streakDays: _streakDays(daily),
      aiCoachMessage: _aiCoachMessage,
      sessions: List<ExerciseSession>.of(_sessions),
    );
  }

  /// 스택 차트의 세 시리즈(유산소·근력·스트레칭) 중 운동 유형에 맞는 버킷.
  List<double> _bucketFor(
    ExerciseType type,
    List<double> cardio,
    List<double> strength,
    List<double> stretching,
  ) => switch (type) {
    ExerciseType.cardio || ExerciseType.walking => cardio,
    ExerciseType.strength => strength,
    ExerciseType.stretching || ExerciseType.yoga => stretching,
    ExerciseType.other => cardio,
  };

  /// 운동한 요일 중 가장 긴 연속 구간 길이 → "N일 연속". 시드(월·화·목·금·
  /// 토·일 활성)에서는 목~일 4일이 최장 연속이라 초기값 4와 일치한다.
  int _streakDays(List<double> daily) {
    int best = 0;
    int run = 0;
    for (final double m in daily) {
      if (m > 0) {
        run += 1;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  int _nonNeg(int v) => v < 0 ? 0 : v;
}
