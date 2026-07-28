import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';

void main() {
  test('dietTodayProvider returns mock day (stub repo)', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        // Default repo is DioDietRepository (needs db + dio overrides);
        // for this unit test the in-memory mock from stage 4 is enough.
        dietRepositoryProvider.overrideWithValue(MockDietRepository()),
      ],
    );
    addTearDown(container.dispose);

    final day = await container.read(dietTodayProvider.future);
    expect(day, isA<DietDay>());
    expect(day.entries.length, 2);
    expect(
      day.entries.map((DietEntry e) => e.mealType),
      containsAll(<MealType>[MealType.breakfast, MealType.lunch]),
    );
    expect(day.totalCalories, 967);
    expect(day.totalSodiumMg, 3421);
    expect(day.aiCoachMessage, isNotEmpty);
  });
}
