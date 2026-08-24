import 'package:demo_fixture/demo_fixture.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';

/// In-memory stateful mock for demo mode (`useMockApi`). The week it starts
/// from is **김민수의 공유 픽스처**(`shared/demo_fixture`)이고, 그 위에서
/// add/update/delete 를 앱 세션 동안 메모리로 이어받아 주간 요약·차트·횟수가
/// 앱에서 한 편집을 그대로 따라간다(#294).
///
/// 픽스처를 읽는 이유: 예전에는 이 목업이 "오늘 + 직전 3일" 을 스스로 박아
/// 넣어서, 같은 사람인데 트레이너웹은 6회·사용자앱은 4회로 갈렸다(#771).
/// 식단·홈 요약은 이미 픽스처 하나를 보고 있었고 운동만 빠져 있었다(#757).
///
/// [_sessions] is the single source of truth for the live week: per-day
/// minutes, the stacked-chart series (유산소/근력/스트레칭), per-day calories,
/// and the weekly totals are all derived from it in [_buildWeek], keeping the
/// invariant `daily == cardio + strength + stretching` for every day.
class MockExerciseRepository implements ExerciseRepository {
  /// [today] defaults to the real date; tests inject a fixed date so the
  /// date-relative fixture stays deterministic. [fixture] defaults to the
  /// bundled 김민수 픽스처.
  MockExerciseRepository({DateTime? today, DemoFixture? fixture})
    : _today = _dateOnly(today ?? nowKst()),
      _todayIdx = (today ?? nowKst()).weekday - 1,
      _fixture = fixture ?? DemoFixture.load() {
    _sessions.addAll(_sessionsForWeek(0));
    _totalCalories = _sessions.fold<int>(
      0,
      (int acc, ExerciseSession s) => acc + s.calories,
    );
  }

  /// Today's weekday index (0 = Mon … 6 = Sun).
  final int _todayIdx;

  /// 자정으로 자른 오늘. 픽스처의 상대 날짜를 실제 날짜로 붙이는 기준이다.
  final DateTime _today;

  final DemoFixture _fixture;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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

  /// [weeksAgo] 주 전의 세션. 픽스처가 **실제로 한** 운동만 갖고 있으므로 못 한
  /// 항목은 여기에 없다 — 이행률 67% 인 날의 주간 시간이 100% 로 잡히지 않는다.
  ///
  /// 하루에 같은 종류가 둘일 수 있어(PT 날의 레그프레스·레그컬은 둘 다 근력)
  /// 종류로 합친다. 주간 활동 그래프가 하루·종류당 한 칸을 그리는 규칙이고,
  /// 사용자앱의 drift 시드(`seed_data.dart`)도 같은 규칙으로 쌓는다.
  List<ExerciseSession> _sessionsForWeek(int weeksAgo) {
    final String weekStart = _ymd(
      _addDays(_today, -(_todayIdx + 7 * weeksAgo)),
    );
    final List<ExerciseSession> out = <ExerciseSession>[];
    for (final FixtureDay day
        in _fixture
            .daysFor(_today)
            .where((FixtureDay d) => d.weekStart == weekStart)) {
      final Map<ExerciseType, List<FixtureExercise>> byType =
          <ExerciseType, List<FixtureExercise>>{};
      for (final FixtureExercise e in day.doneExercises) {
        byType.putIfAbsent(_typeOf(e), () => <FixtureExercise>[]).add(e);
      }
      for (final MapEntry<ExerciseType, List<FixtureExercise>> entry
          in byType.entries) {
        out.add(
          ExerciseSession(
            id: 'seed-ex-${day.date}-${entry.key.name}',
            dayLabel: day.dayLabel,
            dateLabel: _dateLabel(day.date),
            // PT 날만 시각이 있다. 자율 운동은 픽스처가 시각을 갖지 않는다.
            timeLabel: day.isPt ? '18:00' : null,
            type: entry.key,
            minutes: entry.value.fold<int>(
              0,
              (int sum, FixtureExercise e) => sum + e.minutes,
            ),
            calories: entry.value.fold<int>(
              0,
              (int sum, FixtureExercise e) => sum + e.calories,
            ),
            items: <String>[
              for (final FixtureExercise e in entry.value) e.name,
            ],
            // 근력은 세트가 값이다. 이름에 적힌 `4세트` 를 화면이 다시 세지
            // 않도록 픽스처의 수를 그대로 옮긴다.
            sets: entry.value.any((FixtureExercise e) => e.sets != null)
                ? entry.value.fold<int>(
                    0,
                    (int sum, FixtureExercise e) => sum + (e.sets ?? 0),
                  )
                : null,
          ),
        );
      }
    }
    // 최근 요일이 위로 — 프로토타입의 오늘 / 어제 / 그 이전 묶음이 위에서
    // 아래로 읽힌다.
    out.sort(
      (ExerciseSession a, ExerciseSession b) =>
          _dayLabels.indexOf(b.dayLabel) - _dayLabels.indexOf(a.dayLabel),
    );
    return out;
  }

  /// 픽스처의 종류 문자열(`cardio`|`strength`|`flexibility`) → [ExerciseType].
  ///
  /// 옛 값(`walking`·`yoga`·`stretching`)도 읽어 준다 — 픽스처는 표준 어휘로
  /// 옮겼지만(#997) 손으로 고친 사본이나 예전 캐시가 남아 있을 수 있다.
  ExerciseType _typeOf(FixtureExercise e) => switch (e.type) {
    'cardio' || 'walking' => ExerciseType.cardio,
    'strength' => ExerciseType.strength,
    'flexibility' || 'stretching' || 'yoga' => ExerciseType.stretching,
    _ => ExerciseType.other,
  };

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
  Future<ExerciseWeek> fetchWeek(DateTime weekStart) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final int weeksAgo = _weeksAgo(weekStart);
    // 이번 주(또는 미래)는 CRUD 가 반영된 살아 있는 주다.
    if (weeksAgo <= 0) return _buildWeek();
    return _pastWeek(weeksAgo);
  }

  /// [weekStart] 가 이번 주에서 몇 주 전인지. 이번 주면 0.
  int _weeksAgo(DateTime weekStart) {
    final DateTime thisMonday = _addDays(_today, -_todayIdx);
    final int days = thisMonday.difference(_dateOnly(weekStart)).inDays;
    return days <= 0 ? 0 : (days / 7).round();
  }

  /// 지난 주의 기록. 이번 주와 같은 픽스처에서 오므로 주간 비교가 실제 기록
  /// 끼리의 비교다. 픽스처가 덮는 주(`historyWeeks`)를 넘어가면 빈 주다 —
  /// 없는 기록을 지어내면 트레이너웹과 다시 갈린다.
  ///
  /// 인메모리 CRUD 는 이번 주에만 적용된다.
  ExerciseWeek _pastWeek(int weeksAgo) => _weekFrom(
    _sessionsForWeek(weeksAgo),
    aiCoachMessage: '지난 기록이에요. 이번 주와 견줘 보면 흐름이 보여요.',
  );

  /// 세션 카드 위의 날짜 라벨. LocalApiInterceptor·FastAPI 와 같은 규칙이라
  /// 목업으로 보던 화면과 실 경로로 보는 화면의 문구가 같다.
  String _dateLabel(String date) {
    final DateTime parsed = DateTime.parse(date);
    final int diff = _today.difference(_dateOnly(parsed)).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${parsed.month}월 ${parsed.day}일';
  }

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    int? sets,
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
      sets: _setsFor(type, sets),
    );
    _sessions.add(session);
    _totalCalories += calories;
    return session;
  }

  /// 저장할 세트 수. 근력이 아닌 유형에서 온 값은 버린다 — 서버(`_sets_for`)와
  /// 같은 규칙이라야 데모와 실 API 가 같은 기록을 남긴다. (#1262)
  int? _setsFor(ExerciseType type, int? sets) =>
      type == ExerciseType.strength ? sets : null;

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
    int? sets,
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
      sets: _setsFor(type, sets),
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
  ExerciseWeek _buildWeek() => _weekFrom(
    _sessions,
    // 이번 주 총 칼로리만 CRUD 델타로 따로 유지된다(세션 합과 어긋날 수 있는
    // 시드 헤드라인이라 그대로 넘긴다).
    totalCalories: _totalCalories,
    aiCoachMessage: _aiCoachMessage,
  );

  /// [sessions] 에서 한 주의 파생값을 만든다. 이번 주와 지난 주가 같은 규칙을
  /// 쓰므로 두 화면의 수치 정의가 어긋나지 않는다.
  ExerciseWeek _weekFrom(
    List<ExerciseSession> sessions, {
    int? totalCalories,
    required String aiCoachMessage,
  }) {
    final int n = _dayLabels.length;
    final List<double> daily = List<double>.filled(n, 0);
    final List<double> dailyCal = List<double>.filled(n, 0);
    final List<double> cardio = List<double>.filled(n, 0);
    final List<double> strength = List<double>.filled(n, 0);
    final List<double> stretching = List<double>.filled(n, 0);
    final List<double> other = List<double>.filled(n, 0);
    final List<double> strengthSets = List<double>.filled(n, 0);
    int totalMinutes = 0;

    for (final ExerciseSession s in sessions) {
      final int i = _dayLabels.indexOf(s.dayLabel);
      if (i >= 0) {
        daily[i] += s.minutes;
        dailyCal[i] += s.calories;
        _bucketFor(s.type, cardio, strength, stretching, other)[i] += s.minutes;
        if (s.type == ExerciseType.strength) {
          strengthSets[i] +=
              s.sets ?? setsFromStrengthMinutes(s.minutes.toDouble());
        }
      }
      totalMinutes += s.minutes;
    }

    return ExerciseWeek(
      dailyMinutes: daily,
      dailyCalories: dailyCal,
      cardioMinutes: cardio,
      strengthMinutes: strength,
      stretchingMinutes: stretching,
      otherMinutes: other,
      strengthSets: strengthSets,
      dayLabels: List<String>.of(_dayLabels),
      totalMinutes: totalMinutes,
      totalCalories:
          totalCalories ??
          sessions.fold<int>(0, (int a, ExerciseSession s) => a + s.calories),
      streakDays: longestActiveStreak(daily),
      aiCoachMessage: aiCoachMessage,
      sessions: List<ExerciseSession>.of(sessions),
    );
  }

  /// 유형별 시리즈(유산소·근력·유연성·기타) 중 운동 유형에 맞는 버킷.
  ///
  /// `기타` 는 예전에 유산소에 섞어 넣었는데, 목표가 없는 운동이 유산소 달성률을
  /// 올려 버렸다. 이제 제 버킷을 갖는다.
  List<double> _bucketFor(
    ExerciseType type,
    List<double> cardio,
    List<double> strength,
    List<double> stretching,
    List<double> other,
  ) => switch (type) {
    ExerciseType.cardio || ExerciseType.walking => cardio,
    ExerciseType.strength => strength,
    ExerciseType.stretching || ExerciseType.yoga => stretching,
    ExerciseType.other => other,
  };

  int _nonNeg(int v) => v < 0 ? 0 : v;
}
