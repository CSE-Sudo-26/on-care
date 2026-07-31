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

/// Bonus calories from checked AI routines, added to today's home trend bar.
final exerciseTodayBonusCaloriesProvider = Provider<int>((ref) {
  final List<bool> done = ref.watch(exerciseRoutineDoneProvider);
  int kcal = 0;
  for (int i = 0; i < done.length && i < kAiRoutineDeltas.length; i++) {
    if (done[i]) kcal += kAiRoutineDeltas[i].calories;
  }
  return kcal;
}, name: 'exerciseTodayBonusCalories');

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
