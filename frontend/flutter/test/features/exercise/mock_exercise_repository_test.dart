import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

void main() {
  group('MockExerciseRepository keeps CRUD in memory (#294)', () {
    test('addSession persists and updates derived totals/chart/count', () async {
      final repo = MockExerciseRepository();
      final ExerciseWeek before = await repo.fetchThisWeek();
      expect(before.sessions.length, 6);
      expect(before.workoutCount, 6);
      expect(before.totalMinutes, 315);
      // 수요일(index 2)은 시드에서 휴식일.
      expect(before.dailyMinutes[2], 0);
      expect(before.streakDays, 4); // 목·금·토·일

      final ExerciseSession added = await repo.addSession(
        type: ExerciseType.cardio,
        minutes: 30,
        calories: 200,
        dayLabel: '수',
      );

      final ExerciseWeek after = await repo.fetchThisWeek();
      expect(after.sessions.length, 7);
      expect(after.sessions.map((ExerciseSession s) => s.id), contains(added.id));
      expect(after.totalMinutes, 345);
      expect(after.totalCalories, 2180);
      expect(after.dailyMinutes[2], 30);
      expect(after.cardioMinutes[2], 30);
      // 수요일이 채워져 월~일 전 요일 활성 → 연속 7일.
      expect(after.workoutCount, 7);
      expect(after.streakDays, 7);
    });

    test('deleteSession removes it and restores the totals', () async {
      final repo = MockExerciseRepository();
      final ExerciseSession added = await repo.addSession(
        type: ExerciseType.strength,
        minutes: 20,
        calories: 150,
        dayLabel: '수',
      );
      expect((await repo.fetchThisWeek()).sessions.length, 7);

      await repo.deleteSession(added.id!);

      final ExerciseWeek after = await repo.fetchThisWeek();
      expect(after.sessions.length, 6);
      expect(after.sessions.map((ExerciseSession s) => s.id), isNot(contains(added.id)));
      expect(after.totalMinutes, 315);
      expect(after.totalCalories, 1980);
      expect(after.dailyMinutes[2], 0);
      expect(after.streakDays, 4);
    });

    test('updateSession edits an existing session and re-derives totals', () async {
      final repo = MockExerciseRepository();
      await repo.updateSession(
        id: 's-mon',
        type: ExerciseType.cardio,
        minutes: 100, // 40 → 100
        calories: 700, // 300 → 700
        dayLabel: '월',
      );

      final ExerciseWeek after = await repo.fetchThisWeek();
      expect(after.sessions.length, 6); // 개수 불변
      expect(after.totalMinutes, 375); // 315 - 40 + 100
      expect(after.totalCalories, 2380); // 1980 - 300 + 700
      expect(after.dailyMinutes[0], 100);
    });

    test('deleting an unknown id is a no-op', () async {
      final repo = MockExerciseRepository();
      await repo.deleteSession('does-not-exist');
      final ExerciseWeek after = await repo.fetchThisWeek();
      expect(after.sessions.length, 6);
      expect(after.totalMinutes, 315);
    });

    test(
      'daily == cardio + strength + stretching holds after seed edit/delete (리뷰 #294)',
      () async {
        void expectInvariant(ExerciseWeek w) {
          for (int i = 0; i < w.dailyMinutes.length; i++) {
            expect(
              w.cardioMinutes[i] +
                  w.strengthMinutes[i] +
                  w.stretchingMinutes[i],
              w.dailyMinutes[i],
              reason: '요일 index $i 의 유형별 합이 일별 총합과 어긋납니다.',
            );
          }
        }

        final repo = MockExerciseRepository();
        expectInvariant(await repo.fetchThisWeek());

        // 시드 세션 삭제 후에도 유지. (예전 이중 시드에서는 월요일 세션이 유산소
        // 40분이지만 차트 배열은 유산소30+스트레칭10이라, 삭제하면 일별 0인데
        // 스트레칭 10분이 유령으로 남아 불변식이 깨졌다.)
        await repo.deleteSession('s-mon');
        final ExerciseWeek afterDelete = await repo.fetchThisWeek();
        expectInvariant(afterDelete);
        expect(afterDelete.dailyMinutes[0], 0); // 월요일 세션이 하나뿐 → 완전 0
        expect(afterDelete.cardioMinutes[0], 0);
        expect(afterDelete.stretchingMinutes[0], 0);

        // 시드 세션 유형 변경(근력→스트레칭) 후에도 유지.
        await repo.updateSession(
          id: 's-tue',
          type: ExerciseType.stretching,
          minutes: 60,
          calories: 420,
          dayLabel: '화',
        );
        final ExerciseWeek afterUpdate = await repo.fetchThisWeek();
        expectInvariant(afterUpdate);
        expect(afterUpdate.stretchingMinutes[1], 60);
        expect(afterUpdate.strengthMinutes[1], 0);
      },
    );
  });
}
