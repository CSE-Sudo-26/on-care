import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';

class MockExerciseRepository implements ExerciseRepository {
  const MockExerciseRepository();

  @override
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return ExerciseSession(
      id: 'mock-ex',
      dayLabel: dayLabel,
      type: type,
      minutes: minutes,
      calories: calories,
      intensity: intensity,
      dateLabel: '오늘',
    );
  }

  @override
  Future<ExerciseWeek> fetchThisWeek() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const ExerciseWeek(
      dailyMinutes: <double>[40, 60, 50, 65, 55, 80, 0],
      cardioMinutes: <double>[30, 45, 40, 50, 45, 30, 0],
      strengthMinutes: <double>[0, 10, 0, 10, 5, 30, 0],
      stretchingMinutes: <double>[10, 5, 10, 5, 5, 20, 0],
      dayLabels: <String>['월', '화', '수', '목', '금', '토', '일'],
      totalMinutes: 240,
      totalCalories: 1450,
      streakDays: 3,
      aiCoachMessage: '주간 운동 목표 80%를 달성했어요! 오늘 가볍게 걷기를 더해 100%를 채워봐요.',
      sessions: <ExerciseSession>[
        ExerciseSession(
          id: 's-today',
          dateLabel: '오늘',
          timeLabel: '14:30',
          dayLabel: '월',
          type: ExerciseType.cardio,
          minutes: 45,
          calories: 320,
          items: <String>['러닝머신 30분', '사이클 15분'],
        ),
        ExerciseSession(
          id: 's-yest',
          dateLabel: '어제',
          timeLabel: '18:00',
          dayLabel: '일',
          type: ExerciseType.strength,
          minutes: 60,
          calories: 280,
          items: <String>['스쿼트 3세트', '벤치프레스 3세트', '데드리프트 3세트'],
        ),
        ExerciseSession(
          id: 's-512',
          dateLabel: '5월 12일',
          timeLabel: '15:00',
          dayLabel: '금',
          type: ExerciseType.cardio,
          minutes: 30,
          calories: 250,
          items: <String>['러닝머신 30분'],
        ),
        ExerciseSession(
          id: 's-510',
          dateLabel: '5월 10일',
          timeLabel: '19:00',
          dayLabel: '수',
          type: ExerciseType.strength,
          minutes: 50,
          calories: 360,
          items: <String>['스쿼트 4세트', '데드리프트 3세트'],
        ),
        ExerciseSession(
          id: 's-509',
          dateLabel: '5월 9일',
          timeLabel: '07:30',
          dayLabel: '화',
          type: ExerciseType.cardio,
          minutes: 55,
          calories: 240,
          items: <String>['러닝머신 40분', '사이클 15분'],
        ),
      ],
    );
  }

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<ExerciseSession> updateSession({
    required String id,
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async {
    return ExerciseSession(
      id: id,
      dayLabel: dayLabel,
      type: type,
      minutes: minutes,
      calories: calories,
      intensity: intensity,
      dateLabel: '오늘',
    );
  }
}
