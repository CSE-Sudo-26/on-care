import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

void main() {
  // 시드는 '오늘 + 직전 3일(4일 연속)'을 실제 요일에 맞춰 채운다. 결정적 검증을
  // 위해 고정 금요일(2024-01-05, weekday=금 → index 4)을 주입한다.
  // 활성일: 화(index1)·수(2)·목(3)·금/오늘(4).
  final DateTime friday = DateTime(2024, 1, 5);
  MockExerciseRepository repo() => MockExerciseRepository(today: friday);

  group('MockExerciseRepository seeds a real-date 4-day streak (#294)', () {
    test('seed totals reflect 오늘 + 직전 3일', () async {
      final ExerciseWeek w = await repo().fetchThisWeek();
      // 화3 + 수3 + 목3 + 금1(오늘 PT) = 10 세션.
      expect(w.sessions.length, 10);
      expect(w.workoutCount, 4); // 활성 일수 화·수·목·금
      expect(w.streakDays, 4);
      expect(w.totalMinutes, 210); // 45 + 55 + 60 + 50
      expect(w.totalCalories, 1675); // 330 + 387 + 438 + 520
      // 요일별(월..일) 분: 월0 화45 수55 목60 금50 토0 일0.
      expect(w.dailyMinutes, <double>[0, 45, 55, 60, 50, 0, 0]);
      // 요일별 칼로리.
      expect(w.dailyCalories, <double>[0, 330, 387, 438, 520, 0, 0]);
    });

    test('daily == cardio + strength + stretching for every day', () async {
      final ExerciseWeek w = await repo().fetchThisWeek();
      for (int i = 0; i < w.dailyMinutes.length; i++) {
        expect(
          w.cardioMinutes[i] + w.strengthMinutes[i] + w.stretchingMinutes[i],
          w.dailyMinutes[i],
          reason: '요일 index $i 유형 합이 일별 총합과 어긋납니다.',
        );
      }
    });
  });

  group('CRUD keeps derived totals/chart in memory (#294)', () {
    test('addSession persists and updates totals/chart/count', () async {
      final MockExerciseRepository r = repo();
      expect((await r.fetchThisWeek()).sessions.length, 10);

      final ExerciseSession added = await r.addSession(
        type: ExerciseType.cardio,
        minutes: 30,
        calories: 200,
        dayLabel: '월', // 휴식일 → 새 활성일
      );

      final ExerciseWeek after = await r.fetchThisWeek();
      expect(after.sessions.length, 11);
      expect(
        after.sessions.map((ExerciseSession s) => s.id),
        contains(added.id),
      );
      expect(after.totalMinutes, 240);
      expect(after.totalCalories, 1875);
      expect(after.dailyMinutes[0], 30);
      expect(after.dailyCalories[0], 200);
      expect(after.cardioMinutes[0], 30);
      expect(after.workoutCount, 5);
    });

    test('deleteSession removes it and restores the totals', () async {
      final MockExerciseRepository r = repo();
      // s-d1-0 = 목요일 유산소 45분/328kcal.
      await r.deleteSession('s-d1-0');

      final ExerciseWeek after = await r.fetchThisWeek();
      expect(after.sessions.length, 9);
      expect(
        after.sessions.map((ExerciseSession s) => s.id),
        isNot(contains('s-d1-0')),
      );
      expect(after.totalMinutes, 210 - 45);
      expect(after.totalCalories, 1675 - 328);
      expect(after.dailyMinutes[3], 15); // 목: 근력10 + 스트레칭5
      expect(after.cardioMinutes[3], 0);
    });

    test('deleting an unknown id is a no-op', () async {
      final MockExerciseRepository r = repo();
      await r.deleteSession('does-not-exist');
      final ExerciseWeek after = await r.fetchThisWeek();
      expect(after.sessions.length, 10);
      expect(after.totalMinutes, 210);
    });

    test('updateSession edits a session and re-derives totals', () async {
      final MockExerciseRepository r = repo();
      // 오늘 PT(s-today) 근력 50분/520kcal → 80분/700kcal.
      await r.updateSession(
        id: 's-today',
        type: ExerciseType.strength,
        minutes: 80,
        calories: 700,
        dayLabel: '금',
      );

      final ExerciseWeek after = await r.fetchThisWeek();
      expect(after.sessions.length, 10); // 개수 불변
      expect(after.totalMinutes, 210 - 50 + 80);
      expect(after.totalCalories, 1675 - 520 + 700);
      expect(after.strengthMinutes[4], 80);
      expect(after.dailyMinutes[4], 80);
    });
  });
}
