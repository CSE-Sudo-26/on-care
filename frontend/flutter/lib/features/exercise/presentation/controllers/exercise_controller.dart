import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/exercise/data/kakao_gym_demo_profile.dart';
import 'package:oncare/features/exercise/data/repositories/dio_exercise_repository.dart';
import 'package:oncare/features/exercise/data/repositories/dio_gym_repository.dart';
import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/gym_search_area.dart';
import 'package:oncare/features/exercise/domain/entities/my_reservation.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/entities/trainer_slot.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';
import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/domain/entities/place_query.dart';
import 'package:oncare/features/place/presentation/controllers/place_controller.dart';

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

/// 그 주의 월요일. 주 단위 조회의 키다.
DateTime mondayOfWeek(DateTime date) {
  final DateTime d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// 지난 주 운동 기록. 이번 주는 [exerciseWeekViewProvider] 가 담당하므로 여기서
/// 다루지 않는다 — 오늘 체크한 AI 추천 운동이 더해진 값과 두 벌이 되면 같은 주가
/// 화면마다 다른 수치를 갖게 된다(#671).
final exercisePastWeekProvider = FutureProvider.family<ExerciseWeek, DateTime>((
  ref,
  DateTime weekStart,
) {
  return ref.watch(exerciseRepositoryProvider).fetchWeek(weekStart);
}, name: 'exercisePastWeek');

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

/// 헬스장·트레이너 디렉터리. 실 API 는 `/gyms`·`/trainers`(#324).
///
/// 데모(mock) 경로를 유지하는 이유: `LocalApiInterceptor` 에 `/gyms` 계열 핸들러가
/// 없어 데모에서 실 repository 를 쓰면 요청이 갈 곳이 없다. 시드가 mock 과 같은
/// id·문안이라 두 경로의 화면은 같다.
final gymRepositoryProvider = Provider<GymRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    // 한 인스턴스를 provider 수명 동안 유지해, 연결 해제 상태가 MY 탭과
    // 운동 탭에 함께 반영된다.
    return MockGymRepository();
  }
  return DioGymRepository(ref.watch(dioProvider));
}, name: 'gymRepository');

final myGymProvider = FutureProvider<Gym?>((ref) {
  return ref.watch(gymRepositoryProvider).fetchMyGym();
}, name: 'myGym');

final nearbyGymsProvider = FutureProvider<List<Gym>>((ref) {
  return ref.watch(gymRepositoryProvider).fetchNearby();
}, name: 'nearbyGyms');

/// 헬스장 찾기의 카카오 Local 조회 조건. 좌표는 지도 중심·실 API 조회와 같은
/// 상수를 쓴다(`gym_search_area.dart`) — 따로 두면 조용히 어긋난다.
const PlaceQuery kGymFinderArea = PlaceQuery(
  lat: kGymSearchLat,
  lng: kGymSearchLng,
  category: PlaceCategory.fitness,
);

/// 카카오 Local 이 준 주변 헬스장을 [Gym] 형태로 옮긴다.
///
/// 이름·주소·거리·좌표는 카카오 실데이터다. 카카오가 주지 않는 평점·전문분야·
/// 영업시간은 [allowDemoProfile] 일 때만 [kKakaoGymDemoProfiles] 의 시연용 값으로
/// 채운다. **실 API 응답에는 붙이지 않는다** — 지어낸 값이 실재 업체의 사실
/// 정보처럼 보이면 안 되기 때문이다(CodeRabbit 리뷰). 값이 없으면 비워 두고,
/// 평점 0 이면 UI 가 뱃지를 감춘다.
///
/// 소속 트레이너는 [Gym] 이 아니라 [Trainer] 에 있으므로 `MockGymRepository` 가
/// gymId 로 들고 있다.
Gym _gymFromPlace(Place p, {required bool allowDemoProfile}) {
  final KakaoGymDemoProfile? demo = allowDemoProfile
      ? kKakaoGymDemoProfiles[p.id]
      : null;
  return Gym(
    id: p.id,
    name: p.name,
    address: p.address,
    distanceKm: p.distanceMeters / 1000,
    rating: demo?.rating ?? 0,
    tags: demo?.tags ?? const <String>[],
    phone: demo?.phone,
    weekdayHours: demo?.weekdayHours,
    weekendHours: demo?.weekendHours,
    lat: p.lat,
    lng: p.lng,
  );
}

String _gymNameKey(String name) => name.replaceAll(RegExp(r'\s+'), '');

/// 헬스장 찾기 전용 목록 — 제휴 헬스장(평점·트레이너 보유)을 앞에 두고,
/// 카카오 Local 의 주변 헬스장을 뒤에 이어 붙인다.
///
/// [nearbyGymsProvider] 를 그대로 두는 이유: 트레이너 목록·상담 신청이 같은
/// provider 를 보므로, 거기에 카카오 결과를 섞으면 그 화면들이 흐트러진다.
final gymFinderResultsProvider = FutureProvider<List<Gym>>((ref) async {
  final List<Gym> partners = await ref.watch(nearbyGymsProvider.future);
  // 시연용 보강값은 데모(mock) 경로에서만 붙인다.
  final bool demo = ref.watch(appConfigProvider).useMockApi;

  List<Gym> discovered = const <Gym>[];
  try {
    final List<Place> places = await ref
        .watch(placeRepositoryProvider)
        .nearbyPlaces(kGymFinderArea);
    discovered = places
        .map((Place p) => _gymFromPlace(p, allowDemoProfile: demo))
        .toList();
  } on Object {
    // 카카오가 실패해도 제휴 목록은 그대로 보여준다(#329 폴백 요건).
  }

  // 제휴 헬스장이 카카오에도 잡히면 중복이므로, 제휴 쪽(정보가 더 많다)을 남긴다.
  final Set<String> seen = partners.map((Gym g) => _gymNameKey(g.name)).toSet();
  return <Gym>[
    ...partners,
    for (final Gym g in discovered)
      if (seen.add(_gymNameKey(g.name))) g,
  ];
}, name: 'gymFinderResults');

/// 담당 트레이너. 헬스장과 별도 provider 라, 트레이너만 해제해도 헬스장
/// 카드는 그대로 남는다.
final myTrainerProvider = FutureProvider<Trainer?>((ref) {
  return ref.watch(gymRepositoryProvider).fetchMyTrainer();
}, name: 'myTrainer');

/// 한 헬스장에 소속된 트레이너 전원. 헬스장 상세의 소속 트레이너 목록이 읽는다.
final gymTrainersProvider = FutureProvider.family<List<Trainer>, String>((
  ref,
  String gymId,
) {
  return ref.watch(gymRepositoryProvider).fetchTrainersByGym(gymId);
}, name: 'gymTrainers');

/// 트레이너 상세가 자기 id 로 직접 읽는다.
final trainerProvider = FutureProvider.family<Trainer?, String>((
  ref,
  String trainerId,
) {
  return ref.watch(gymRepositoryProvider).fetchTrainer(trainerId);
}, name: 'trainer');

final recommendedTrainersProvider = FutureProvider<List<Trainer>>((ref) {
  return ref.watch(gymRepositoryProvider).fetchRecommendedTrainers();
}, name: 'recommendedTrainers');

/// "트레이너 찾기" 목록이 읽는 전체 디렉터리.
final allTrainersProvider = FutureProvider<List<Trainer>>((ref) {
  return ref.watch(gymRepositoryProvider).fetchAllTrainers();
}, name: 'allTrainers');

/// 한 트레이너의 예약 가능 시간. 트레이너별로 다르므로 family 로 둔다.
/// 예약이 성사되면 이 provider 를 invalidate 해서 잔여 자리를 다시 읽는다.
final trainerSlotsProvider = FutureProvider.family<List<TrainerSlot>, String>((
  ref,
  String trainerId,
) {
  return ref.watch(gymRepositoryProvider).fetchSlots(trainerId);
}, name: 'trainerSlots');

/// 내가 잡아 둔 예약. 예약 패널이 '내 자리'를 표시하고 취소를 걸 근거다. (#502)
///
/// 슬롯 목록과 따로 두는 이유: 슬롯은 트레이너별이고 예약은 회원별이라 무효화
/// 시점이 다르다. 취소하면 둘 다 invalidate 해야 잔여 자리와 내 예약이 함께
/// 맞는다.
final myReservationsProvider = FutureProvider<List<MyReservation>>((ref) {
  return ref.watch(gymRepositoryProvider).fetchMyReservations();
}, name: 'myReservations');
