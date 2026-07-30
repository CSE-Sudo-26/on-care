import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';

void main() {
  test('exerciseWeekProvider provides 7 days, sane totals', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        // Production repo is DioExerciseRepository (needs dio + db);
        // unit test only needs the React-shaped in-memory mock.
        exerciseRepositoryProvider.overrideWithValue(
          MockExerciseRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final week = await container.read(exerciseWeekProvider.future);
    expect(week.dailyMinutes.length, 7);
    expect(week.dayLabels.length, 7);
    expect(week.totalMinutes, 315);
    expect(week.totalCalories, 1980);
    expect(week.streakDays, 4);
    expect(week.aiCoachMessage, isNotEmpty);
    expect(week.sessions, isNotEmpty);
    // Stacked-chart series should line up with the bar chart x-axis.
    expect(week.cardioMinutes.length, week.dailyMinutes.length);
    expect(week.strengthMinutes.length, week.dailyMinutes.length);
    expect(week.stretchingMinutes.length, week.dailyMinutes.length);
  });
}
