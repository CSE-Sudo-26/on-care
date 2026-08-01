import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/exercise/data/repositories/dio_exercise_repository.dart';
import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  // Local/demo mode serves the mock "오늘 PT 받은 날" scenario week (12회차 PT,
  // 코치 피드백·짬뽕 식단 반영 AI 루틴) so the exercise tab renders the intended
  // context with no backend. The real REST repo is used otherwise.
  if (ref.watch(appConfigProvider).useMockApi) {
    // One instance per provider lifetime so in-memory CRUD (add/edit/delete)
    // persists across `exerciseWeekProvider` invalidations for the session.
    return MockExerciseRepository();
  }
  return DioExerciseRepository(ref.watch(dioProvider));
}, name: 'exerciseRepository');

final exerciseWeekProvider = FutureProvider<ExerciseWeek>((ref) {
  return ref.watch(exerciseRepositoryProvider).fetchThisWeek();
}, name: 'exerciseWeek');

/// Today's activity delta for one AI recommendation. Shared so the exercise
/// tab's check and the home "주간 추이" chart read the same numbers.
class AiRoutineDelta {
  const AiRoutineDelta({
    required this.cardioMin,
    required this.stretchMin,
    required this.calories,
  });
  final double cardioMin;
  final double stretchMin;
  final int calories;
}

/// [0] = 어깨 관절 보호 스트레칭(8분), [1] = 가벼운 인터벌 러닝(30분·250kcal).
const List<AiRoutineDelta> kAiRoutineDeltas = <AiRoutineDelta>[
  AiRoutineDelta(cardioMin: 0, stretchMin: 8, calories: 45),
  AiRoutineDelta(cardioMin: 30, stretchMin: 0, calories: 250),
];

/// Completion state of the two AI recommended workouts. Owned here (not in
/// the exercise tab's local state) so checking one on the 운동 tab also
/// updates the home 운동 카드's 주간 추이 today bar.
final exerciseRoutineDoneProvider = StateProvider<List<bool>>(
  (ref) => <bool>[false, false],
  name: 'exerciseRoutineDone',
);

/// Today's activity added by the checked AI routines, summed across
/// [kAiRoutineDeltas].
class ExerciseTodayBonus {
  const ExerciseTodayBonus({
    this.cardioMinutes = 0,
    this.stretchMinutes = 0,
    this.calories = 0,
  });

  final double cardioMinutes;
  final double stretchMinutes;
  final int calories;

  double get minutes => cardioMinutes + stretchMinutes;
  bool get isEmpty => minutes == 0 && calories == 0;
}

/// Activity delta from the AI routines checked today.
final exerciseTodayBonusProvider = Provider<ExerciseTodayBonus>((ref) {
  final List<bool> done = ref.watch(exerciseRoutineDoneProvider);
  double cardio = 0;
  double stretch = 0;
  int kcal = 0;
  for (int i = 0; i < done.length && i < kAiRoutineDeltas.length; i++) {
    if (!done[i]) continue;
    cardio += kAiRoutineDeltas[i].cardioMin;
    stretch += kAiRoutineDeltas[i].stretchMin;
    kcal += kAiRoutineDeltas[i].calories;
  }
  return ExerciseTodayBonus(
    cardioMinutes: cardio,
    stretchMinutes: stretch,
    calories: kcal,
  );
}, name: 'exerciseTodayBonus');

/// [week] with [bonus] folded into today's column and the weekly totals, so
/// the per-day series, the 주간 합계 tiles and the 운동 일수 count all move
/// together instead of the chart alone. Returns [week] untouched when there
/// is nothing to add. [now] is injectable for deterministic tests.
ExerciseWeek applyTodayBonus(
  ExerciseWeek week,
  ExerciseTodayBonus bonus, {
  DateTime? now,
}) {
  final int n = week.dailyMinutes.length;
  if (bonus.isEmpty || n == 0) return week;
  final int today = ((now ?? DateTime.now()).weekday - 1).clamp(0, n - 1);

  /// Adds [delta] to today's slot, leaving series the payload omitted
  /// (length mismatch) alone so a partial payload can't be misaligned.
  List<double> bump(List<double> series, double delta) {
    if (series.length != n || delta == 0) return series;
    return <double>[
      for (int i = 0; i < n; i++) i == today ? series[i] + delta : series[i],
    ];
  }

  final List<double> dailyMinutes = bump(week.dailyMinutes, bonus.minutes);

  return ExerciseWeek(
    sessions: week.sessions,
    dailyMinutes: dailyMinutes,
    dailyCalories: bump(week.dailyCalories, bonus.calories.toDouble()),
    cardioMinutes: bump(week.cardioMinutes, bonus.cardioMinutes),
    strengthMinutes: week.strengthMinutes,
    stretchingMinutes: bump(week.stretchingMinutes, bonus.stretchMinutes),
    dayLabels: week.dayLabels,
    totalMinutes: week.totalMinutes + bonus.minutes.round(),
    totalCalories: week.totalCalories + bonus.calories,
    // 휴식일이던 오늘이 보너스로 활성일이 되면 연속 일수도 늘어야 한다. 저장된
    // 값을 그대로 넘기면 '운동 일수'(dailyMinutes 기반)와 '연속' 카드가 어긋난다.
    streakDays: longestActiveStreak(dailyMinutes),
    aiCoachMessage: week.aiCoachMessage,
  );
}

/// The week as the UI shows it: stored data plus today's checked AI routines.
/// 홈 운동 카드와 운동 탭이 모두 이 provider 를 읽어, 오늘 막대·도넛뿐 아니라
/// 주간 시간·칼로리·일수 합계까지 하나의 값에서 나온다. Invalidate the
/// underlying [exerciseWeekProvider] to refetch.
final exerciseWeekViewProvider = Provider<AsyncValue<ExerciseWeek>>((ref) {
  final ExerciseTodayBonus bonus = ref.watch(exerciseTodayBonusProvider);
  return ref
      .watch(exerciseWeekProvider)
      .whenData((ExerciseWeek w) => applyTodayBonus(w, bonus));
}, name: 'exerciseWeekView');

/// Gym data has no backend endpoint yet — the prototype shipped only
/// mock data, so wire the page to a static repository for now. A real
/// `DioGymRepository` can be swapped in once `/gyms/*` lands.
final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => const MockGymRepository(),
  name: 'gymRepository',
);

final myGymProvider = FutureProvider<Gym?>((ref) {
  return ref.watch(gymRepositoryProvider).fetchMyGym();
}, name: 'myGym');

final nearbyGymsProvider = FutureProvider<List<Gym>>((ref) {
  return ref.watch(gymRepositoryProvider).fetchNearby();
}, name: 'nearbyGyms');
