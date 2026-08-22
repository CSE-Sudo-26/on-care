import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';

void main() {
  test('exerciseWeekProvider provides 7 days, sane totals', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        // Production repo is DioExerciseRepository (needs dio + db);
        // unit test only needs the React-shaped in-memory mock.
        // 고정 금요일을 주입해 날짜에 상대적인 시드를 결정적으로 만든다.
        // 값이 픽스처와 맞는지는 mock_exercise_repository_test 가 본다 —
        // 여기에 숫자를 또 적으면 픽스처와 세 벌이 된다.
        exerciseRepositoryProvider.overrideWithValue(
          MockExerciseRepository(today: DateTime(2024, 1, 5)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final week = await container.read(exerciseWeekProvider.future);
    expect(week.dailyMinutes.length, 7);
    expect(week.dayLabels.length, 7);
    expect(week.totalMinutes, greaterThan(0));
    expect(week.totalCalories, greaterThan(0));
    expect(week.streakDays, greaterThan(0));
    expect(week.aiCoachMessage, isNotEmpty);
    expect(week.sessions, isNotEmpty);
    // Stacked-chart series should line up with the bar chart x-axis.
    expect(week.cardioMinutes.length, week.dailyMinutes.length);
    expect(week.strengthMinutes.length, week.dailyMinutes.length);
    expect(week.stretchingMinutes.length, week.dailyMinutes.length);
  });

  group('applyTodayBonus folds checked AI routines into the whole week', () {
    // 고정 금요일(2024-01-05, index 4)로 오늘 열을 결정적으로 만든다.
    final DateTime friday = DateTime(2024, 1, 5);

    Future<ExerciseWeek> seededWeek() async {
      final container = ProviderContainer(
        overrides: <Override>[
          exerciseRepositoryProvider.overrideWithValue(
            MockExerciseRepository(today: friday),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(exerciseWeekProvider.future);
    }

    test('totals, today column and 운동 일수 move together', () async {
      final ExerciseWeek base = await seededWeek();
      // 두 루틴 모두 완료: 스트레칭 8분/45kcal + 유산소 30분/250kcal.
      const ExerciseTodayBonus bonus = ExerciseTodayBonus(
        cardioMinutes: 30,
        stretchMinutes: 8,
        calories: 295,
      );
      final ExerciseWeek out = applyTodayBonus(base, bonus, now: friday);

      expect(out.totalMinutes, base.totalMinutes + 38);
      expect(out.totalCalories, base.totalCalories + 295);
      expect(out.dailyMinutes[4], base.dailyMinutes[4] + 38);
      expect(out.dailyCalories[4], base.dailyCalories[4] + 295);
      expect(out.cardioMinutes[4], base.cardioMinutes[4] + 30);
      expect(out.stretchingMinutes[4], base.stretchingMinutes[4] + 8);
      // 근력은 추천 루틴에 없으므로 그대로.
      expect(out.strengthMinutes, base.strengthMinutes);
      // 다른 요일은 손대지 않는다.
      expect(out.dailyMinutes[3], base.dailyMinutes[3]);
      // 유형별 합 == 일별 총합 불변식 유지(목표 없는 `기타` 포함).
      for (int i = 0; i < out.dailyMinutes.length; i++) {
        expect(
          out.cardioMinutes[i] +
              out.strengthMinutes[i] +
              out.stretchingMinutes[i] +
              (i < out.otherMinutes.length ? out.otherMinutes[i] : 0),
          out.dailyMinutes[i],
          reason: '요일 index $i 유형 합이 일별 총합과 어긋납니다.',
        );
      }
    });

    test('a routine on a rest day counts that day as a workout day', () {
      // 오늘(금, index 4) 기록이 없는 주 — 추천 루틴 체크로 활성 일수가 1 늘어난다.
      const ExerciseWeek rest = ExerciseWeek(
        sessions: <ExerciseSession>[],
        dailyMinutes: <double>[50, 0, 0, 0, 0, 0, 0],
        dailyCalories: <double>[300, 0, 0, 0, 0, 0, 0],
        cardioMinutes: <double>[50, 0, 0, 0, 0, 0, 0],
        strengthMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
        stretchingMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
        dayLabels: <String>['월', '화', '수', '목', '금', '토', '일'],
        totalMinutes: 50,
        totalCalories: 300,
        streakDays: 1,
        aiCoachMessage: 'hi',
      );
      expect(rest.workoutCount, 1);
      final ExerciseWeek out = applyTodayBonus(
        rest,
        const ExerciseTodayBonus(cardioMinutes: 30, calories: 250),
        now: friday,
      );
      expect(out.workoutCount, 2);
      expect(out.totalMinutes, 80);
      expect(out.totalCalories, 550);
      // 월과 금은 떨어져 있으므로 활성 일수는 2여도 '연속'은 1을 유지한다.
      // 활성 일수 합계로 세면 2가 나와 '연속' 카드가 거짓말을 하게 된다.
      expect(out.streakDays, 1);
    });

    test('streak grows with the bonus when it extends a run', () async {
      // 오늘(금, index 4) 직전 목요일까지 이어진 주 — 오늘을 채우면 연속 3일.
      const ExerciseWeek week = ExerciseWeek(
        sessions: <ExerciseSession>[],
        dailyMinutes: <double>[0, 0, 40, 40, 0, 0, 0],
        dailyCalories: <double>[0, 0, 250, 250, 0, 0, 0],
        cardioMinutes: <double>[0, 0, 40, 40, 0, 0, 0],
        strengthMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
        stretchingMinutes: <double>[0, 0, 0, 0, 0, 0, 0],
        dayLabels: <String>['월', '화', '수', '목', '금', '토', '일'],
        totalMinutes: 80,
        totalCalories: 500,
        streakDays: 2,
        aiCoachMessage: 'hi',
      );
      final ExerciseWeek out = applyTodayBonus(
        week,
        const ExerciseTodayBonus(cardioMinutes: 30, calories: 250),
        now: friday,
      );
      expect(out.streakDays, 3);
      expect(out.workoutCount, 3);
    });

    test('no checked routine leaves the week untouched', () async {
      final ExerciseWeek base = await seededWeek();
      expect(
        applyTodayBonus(base, const ExerciseTodayBonus(), now: friday),
        same(base),
      );
    });
  });
}
