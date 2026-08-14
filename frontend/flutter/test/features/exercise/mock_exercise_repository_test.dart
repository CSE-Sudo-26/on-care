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

    test('월요일이면 직전 3일이 이전 주로 빠져 오늘 1건만 남는다', () async {
      // 월요일(2024-01-01, weekday=월 → index 0)을 주입하면 offset 1..3의
      // wi(= -1..-3)가 모두 음수라 _seed 가 건너뛰고, 오늘 PT 1건만 시드된다.
      final ExerciseWeek w =
          await MockExerciseRepository(today: DateTime(2024)) // 2024-01-01(월)
              .fetchThisWeek();
      expect(w.sessions.length, 1);
      expect(w.workoutCount, 1);
      expect(w.streakDays, 1);
      expect(w.dailyMinutes, <double>[50, 0, 0, 0, 0, 0, 0]);
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

  group('fetchWeek 로 지난 주를 조회한다 (#671)', () {
    test('이번 주 월요일을 주면 fetchThisWeek 과 같다', () async {
      final MockExerciseRepository r = repo();
      // 2024-01-05 는 금요일 → 그 주 월요일은 2024-01-01.
      final ExerciseWeek week = await r.fetchWeek(DateTime(2024));
      final ExerciseWeek current = await r.fetchThisWeek();
      expect(week.dailyMinutes, current.dailyMinutes);
      expect(week.totalMinutes, current.totalMinutes);
    });

    test('지난 주는 값이 있고, 이번 주와 다르다', () async {
      final MockExerciseRepository r = repo();
      final ExerciseWeek last = await r.fetchWeek(DateTime(2023, 12, 25));
      final ExerciseWeek current = await r.fetchThisWeek();

      expect(last.totalMinutes, greaterThan(0));
      expect(last.sessions, isNotEmpty);
      expect(
        last.dailyMinutes,
        isNot(current.dailyMinutes),
        reason: '지난 주가 이번 주 복사본이면 주간 비교가 뜻이 없다',
      );
      // 하루 합 = 유형별 합 (이번 주와 같은 규칙).
      for (int i = 0; i < last.dailyMinutes.length; i++) {
        expect(
          last.dailyMinutes[i],
          closeTo(
            last.cardioMinutes[i] +
                last.strengthMinutes[i] +
                last.stretchingMinutes[i],
            0.001,
          ),
        );
      }
      // 지난 주 세션에는 '오늘' 라벨이 붙지 않는다.
      expect(
        last.sessions.every((ExerciseSession s) => s.dateLabel != '오늘'),
        isTrue,
      );
    });

    test('오래된 주일수록 운동량이 줄어든다', () async {
      final MockExerciseRepository r = repo();
      final ExerciseWeek oneWeekAgo = await r.fetchWeek(DateTime(2023, 12, 25));
      final ExerciseWeek fourWeeksAgo = await r.fetchWeek(DateTime(2023, 12, 4));
      expect(fourWeeksAgo.totalMinutes, lessThan(oneWeekAgo.totalMinutes));
    });
  });
}
