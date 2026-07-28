import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';

/// In-memory stateful mock for demo mode (`useMockApi`). Seeds the
/// "상황 1: 오늘 PT 받은 날" scenario, then keeps add/update/delete in memory
/// for the app session so the weekly summary·chart·count reflect edits made
/// through the app (issue #294). A single instance is created by
/// [exerciseRepositoryProvider] and lives for the session, so the drift
/// persists until the app is restarted.
///
/// The seeded per-day arrays are the hand-tuned demo values, so the initial
/// render is unchanged; CRUD only applies deltas on top of them.
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
  final List<double> _dailyMinutes = <double>[40, 60, 0, 65, 55, 45, 50];
  final List<double> _cardioMinutes = <double>[30, 45, 0, 50, 45, 40, 0];
  final List<double> _strengthMinutes = <double>[0, 10, 0, 10, 5, 0, 40];
  final List<double> _stretchingMinutes = <double>[10, 5, 0, 5, 5, 5, 10];
  int _totalMinutes = 315;
  int _totalCalories = 1980;

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

  @override
  Future<ExerciseWeek> fetchThisWeek() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return ExerciseWeek(
      dailyMinutes: List<double>.of(_dailyMinutes),
      cardioMinutes: List<double>.of(_cardioMinutes),
      strengthMinutes: List<double>.of(_strengthMinutes),
      stretchingMinutes: List<double>.of(_stretchingMinutes),
      dayLabels: List<String>.of(_dayLabels),
      totalMinutes: _totalMinutes,
      totalCalories: _totalCalories,
      streakDays: _streakDays(),
      aiCoachMessage: _aiCoachMessage,
      sessions: List<ExerciseSession>.of(_sessions),
    );
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
    _apply(session, 1);
    _sessions.add(session);
    return session;
  }

  @override
  Future<void> deleteSession(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final int idx = _sessions.indexWhere((ExerciseSession s) => s.id == id);
    if (idx < 0) return;
    _apply(_sessions[idx], -1);
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
    if (old != null) {
      _apply(old, -1);
      _apply(updated, 1);
      _sessions[idx] = updated;
    }
    return updated;
  }

  // ── 파생 값 재계산 ────────────────────────────────────────────────

  /// [session]의 시간·칼로리를 요일별 배열과 총계에 [sign](+1/−1)만큼 반영한다.
  void _apply(ExerciseSession session, int sign) {
    final int i = _dayLabels.indexOf(session.dayLabel);
    if (i >= 0) {
      _dailyMinutes[i] = _nonNeg(_dailyMinutes[i] + sign * session.minutes);
      final List<double> bucket = _bucketFor(session.type);
      bucket[i] = _nonNeg(bucket[i] + sign * session.minutes);
    }
    _totalMinutes = _nonNeg(_totalMinutes + sign * session.minutes).toInt();
    _totalCalories = _nonNeg(_totalCalories + sign * session.calories).toInt();
  }

  /// 스택 차트의 세 시리즈(유산소·근력·스트레칭) 중 운동 유형에 맞는 버킷.
  List<double> _bucketFor(ExerciseType type) => switch (type) {
    ExerciseType.cardio || ExerciseType.walking => _cardioMinutes,
    ExerciseType.strength => _strengthMinutes,
    ExerciseType.stretching || ExerciseType.yoga => _stretchingMinutes,
    ExerciseType.other => _cardioMinutes,
  };

  /// 운동한 요일 중 가장 긴 연속 구간 길이 → "N일 연속". 시드(월·화·목·금·
  /// 토·일 활성)에서는 목~일 4일이 최장 연속이라 초기값 4와 일치한다.
  int _streakDays() {
    int best = 0;
    int run = 0;
    for (final double m in _dailyMinutes) {
      if (m > 0) {
        run += 1;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  double _nonNeg(num v) => v < 0 ? 0 : v.toDouble();
}
