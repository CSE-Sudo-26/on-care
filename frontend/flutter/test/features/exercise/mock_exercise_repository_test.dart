import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

void main() {
  group('MockExerciseRepository keeps CRUD in memory (#294)', () {
    // 시드는 월·화·목·금을 유형별(유산소/근력/스트레칭) 여러 세션으로 나눠
    // 담는다(운동 현황 차트의 누적 막대 복원). 하루 총합·주간 총합·연속일은
    // 이전과 동일하고, "운동 횟수"는 세션 수가 아니라 활성 일수(workoutCount).
    test(
      'addSession persists and updates derived totals/chart/count',
      () async {
        final repo = MockExerciseRepository();
        final ExerciseWeek before = await repo.fetchThisWeek();
        // 월2 + 화3 + 목3 + 금3 + 토1 + 일1 = 13 세션.
        expect(before.sessions.length, 13);
        expect(before.workoutCount, 6); // 활성 일수(월화목금토일)
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
        expect(after.sessions.length, 14);
        expect(
          after.sessions.map((ExerciseSession s) => s.id),
          contains(added.id),
        );
        expect(after.totalMinutes, 345);
        expect(after.totalCalories, 2180);
        expect(after.dailyMinutes[2], 30);
        expect(after.cardioMinutes[2], 30);
        // 수요일이 채워져 월~일 전 요일 활성 → 연속 7일.
        expect(after.workoutCount, 7);
        expect(after.streakDays, 7);
      },
    );

    test('deleteSession removes it and restores the totals', () async {
      final repo = MockExerciseRepository();
      final ExerciseSession added = await repo.addSession(
        type: ExerciseType.strength,
        minutes: 20,
        calories: 150,
        dayLabel: '수',
      );
      expect((await repo.fetchThisWeek()).sessions.length, 14);

      await repo.deleteSession(added.id!);

      final ExerciseWeek after = await repo.fetchThisWeek();
      expect(after.sessions.length, 13);
      expect(
        after.sessions.map((ExerciseSession s) => s.id),
        isNot(contains(added.id)),
      );
      expect(after.totalMinutes, 315);
      expect(after.totalCalories, 1980);
      expect(after.dailyMinutes[2], 0);
      expect(after.streakDays, 4);
    });

    test(
      'updateSession edits an existing session and re-derives totals',
      () async {
        final repo = MockExerciseRepository();
        // 월요일 유산소 세션(30분)을 100분으로 수정 → 월 = 유산소100 + 스트레칭10.
        await repo.updateSession(
          id: 's-mon-cardio',
          type: ExerciseType.cardio,
          minutes: 100, // 30 → 100
          calories: 700, // 225 → 700
          dayLabel: '월',
        );

        final ExerciseWeek after = await repo.fetchThisWeek();
        expect(after.sessions.length, 13); // 개수 불변
        expect(after.totalMinutes, 385); // 315 - 30 + 100
        expect(after.totalCalories, 2455); // 1980 - 225 + 700
        expect(after.dailyMinutes[0], 110); // 유산소100 + 스트레칭10
        expect(after.cardioMinutes[0], 100);
        expect(after.stretchingMinutes[0], 10);
      },
    );

    test('deleting an unknown id is a no-op', () async {
      final repo = MockExerciseRepository();
      await repo.deleteSession('does-not-exist');
      final ExerciseWeek after = await repo.fetchThisWeek();
      expect(after.sessions.length, 13);
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

        // 월요일 유산소 세션 삭제 후에도 불변식 유지. 월요일엔 스트레칭 세션이
        // 남아 있으므로 유산소만 0이 되고 스트레칭 10분은 그대로.
        await repo.deleteSession('s-mon-cardio');
        final ExerciseWeek afterDelete = await repo.fetchThisWeek();
        expectInvariant(afterDelete);
        expect(afterDelete.dailyMinutes[0], 10); // 스트레칭 10만 남음
        expect(afterDelete.cardioMinutes[0], 0);
        expect(afterDelete.stretchingMinutes[0], 10);

        // 화요일 근력 세션의 유형을 스트레칭으로 변경 후에도 유지.
        await repo.updateSession(
          id: 's-tue-strength',
          type: ExerciseType.stretching,
          minutes: 10,
          calories: 70,
          dayLabel: '화',
        );
        final ExerciseWeek afterUpdate = await repo.fetchThisWeek();
        expectInvariant(afterUpdate);
        // 화 = 유산소45 + 스트레칭(5+10) = 60, 근력 0.
        expect(afterUpdate.stretchingMinutes[1], 15);
        expect(afterUpdate.strengthMinutes[1], 0);
      },
    );
  });
}
