import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';

/// In-memory stateful mock for demo mode (`useMockApi`). Seeds the
/// "상황 1: 오늘 PT 받은 날" scenario as a **4-day streak ending today**, then
/// keeps add/update/delete in memory for the app session so the weekly
/// summary·chart·count reflect edits made through the app (issue #294).
///
/// The seed is anchored to the real weekday (via [_todayIdx]) so the home
/// 운동 카드와 운동 탭이 같은 '오늘'을 가리킨다. [_sessions] is the single
/// source of truth: per-day minutes, the stacked-chart series
/// (유산소/근력/스트레칭), per-day calories, and the weekly totals are all
/// derived from it in [_buildWeek], keeping the invariant
/// `daily == cardio + strength + stretching` for every day.
class MockExerciseRepository implements ExerciseRepository {
  /// [today] defaults to the real date; tests inject a fixed date so the
  /// date-relative seed stays deterministic.
  MockExerciseRepository({DateTime? today})
    : _todayIdx = (today ?? DateTime.now()).weekday - 1 {
    _sessions.addAll(_seed(_todayIdx));
    _totalCalories = _sessions.fold<int>(
      0,
      (int acc, ExerciseSession s) => acc + s.calories,
    );
  }

  /// Today's weekday index (0 = Mon … 6 = Sun).
  final int _todayIdx;

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

  /// Seeds 오늘 + 직전 3일(4일 연속)을 실제 요일에 맞춰 채운다. offset 0 = 오늘
  /// (12회차 PT·근력 중심), 1..3 = 직전 날(유산소/근력/스트레칭 혼합). 주 시작
  /// (월) 이전으로 넘어가는 offset 은 이번 주 뷰 밖이라 생략한다.
  static List<ExerciseSession> _seed(int todayIdx) {
    const Map<int, List<(ExerciseType, int, int)>> plans =
        <int, List<(ExerciseType, int, int)>>{
          0: <(ExerciseType, int, int)>[(ExerciseType.strength, 50, 520)],
          1: <(ExerciseType, int, int)>[
            (ExerciseType.cardio, 45, 328),
            (ExerciseType.strength, 10, 73),
            (ExerciseType.stretching, 5, 37),
          ],
          2: <(ExerciseType, int, int)>[
            (ExerciseType.cardio, 45, 315),
            (ExerciseType.strength, 5, 36),
            (ExerciseType.stretching, 5, 36),
          ],
          3: <(ExerciseType, int, int)>[
            (ExerciseType.cardio, 30, 225),
            (ExerciseType.strength, 10, 70),
            (ExerciseType.stretching, 5, 35),
          ],
        };
    final List<ExerciseSession> out = <ExerciseSession>[];
    for (final int offset in <int>[3, 2, 1, 0]) {
      final int wi = todayIdx - offset;
      if (wi < 0) continue; // 주 시작(월) 이전은 이번 주 뷰 밖.
      final String label = _dayLabels[wi];
      final bool isToday = offset == 0;
      int k = 0;
      for (final (ExerciseType type, int min, int kcal) in plans[offset]!) {
        out.add(
          ExerciseSession(
            id: isToday ? 's-today' : 's-d$offset-${k++}',
            dayLabel: label,
            dateLabel: isToday ? '오늘' : '$label요일',
            timeLabel: isToday ? '18:00' : null,
            type: type,
            minutes: min,
            calories: kcal,
            items: isToday
                ? const <String>['벤치프레스 40kg 4세트', '덤벨 숄더프레스 10kg 4세트']
                : const <String>[],
          ),
        );
      }
    }
    return out;
  }

  final List<ExerciseSession> _sessions = <ExerciseSession>[];

  int _seq = 0;

  // 주간 소모 칼로리 헤드라인 — 시드 세션 합에서 시작해 CRUD 델타로 유지.
  int _totalCalories = 0;

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

  /// 요일별 시간·칼로리·유형별 시간·총분·연속일을 [_sessions]에서 계산한다.
  /// daily/dailyCal 은 그 날 모든 세션의 합이고, 유형별 버킷 합도 같은 세션에서
  /// 나오므로 `daily[i] == cardio[i] + strength[i] + stretching[i]` 가 성립한다.
  ExerciseWeek _buildWeek() {
    final int n = _dayLabels.length;
    final List<double> daily = List<double>.filled(n, 0);
    final List<double> dailyCal = List<double>.filled(n, 0);
    final List<double> cardio = List<double>.filled(n, 0);
    final List<double> strength = List<double>.filled(n, 0);
    final List<double> stretching = List<double>.filled(n, 0);
    int totalMinutes = 0;

    for (final ExerciseSession s in _sessions) {
      final int i = _dayLabels.indexOf(s.dayLabel);
      if (i >= 0) {
        daily[i] += s.minutes;
        dailyCal[i] += s.calories;
        _bucketFor(s.type, cardio, strength, stretching)[i] += s.minutes;
      }
      totalMinutes += s.minutes;
    }

    return ExerciseWeek(
      dailyMinutes: daily,
      dailyCalories: dailyCal,
      cardioMinutes: cardio,
      strengthMinutes: strength,
      stretchingMinutes: stretching,
      dayLabels: List<String>.of(_dayLabels),
      totalMinutes: totalMinutes,
      totalCalories: _totalCalories,
      streakDays: longestActiveStreak(daily),
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

  int _nonNeg(int v) => v < 0 ? 0 : v;
}
