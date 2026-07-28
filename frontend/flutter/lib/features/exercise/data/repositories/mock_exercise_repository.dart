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
    // "상황 1: 오늘 PT 수업을 받은 날" scenario. Today (일) carries the 12회차 PT
    // session (근력 + 마무리 스트레칭); the weekly summary/chart and AI feedback
    // reflect that. Session count feeds the "이번 주 N회" tile.
    return const ExerciseWeek(
      // 목·금·토·일 4일 연속 운동 → "4일 연속"과 일치.
      dailyMinutes: <double>[40, 60, 0, 65, 55, 45, 50],
      cardioMinutes: <double>[30, 45, 0, 50, 45, 40, 0],
      strengthMinutes: <double>[0, 10, 0, 10, 5, 0, 40],
      stretchingMinutes: <double>[10, 5, 0, 5, 5, 5, 10],
      dayLabels: <String>['월', '화', '수', '목', '금', '토', '일'],
      totalMinutes: 315,
      totalCalories: 1980,
      streakDays: 4,
      aiCoachMessage:
          '12회차 PT 완료! 코치님이 강조하신 어깨 회전근개 스트레칭과 마무리 유산소로 완벽히 정리해보세요.',
      sessions: <ExerciseSession>[
        ExerciseSession(
          id: 's-mon',
          dateLabel: '월요일',
          dayLabel: '월',
          type: ExerciseType.cardio,
          minutes: 40,
          calories: 300,
        ),
        ExerciseSession(
          id: 's-tue',
          dateLabel: '화요일',
          dayLabel: '화',
          type: ExerciseType.strength,
          minutes: 60,
          calories: 420,
        ),
        ExerciseSession(
          id: 's-thu',
          dateLabel: '목요일',
          dayLabel: '목',
          type: ExerciseType.cardio,
          minutes: 65,
          calories: 480,
        ),
        ExerciseSession(
          id: 's-today',
          dateLabel: '오늘',
          timeLabel: '18:00',
          dayLabel: '일',
          type: ExerciseType.strength,
          minutes: 50,
          calories: 520,
          items: <String>['벤치프레스 40kg 4세트', '덤벨 숄더프레스 10kg 4세트'],
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
