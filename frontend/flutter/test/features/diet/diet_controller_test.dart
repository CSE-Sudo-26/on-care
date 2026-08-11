import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';

import '../../helpers/fake_diet_repository.dart';

void main() {
  test('dietTodayProvider returns mock day (stub repo)', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        // Default repo is DioDietRepository (needs db + dio overrides);
        // for this unit test the in-memory mock from stage 4 is enough.
        dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
      ],
    );
    addTearDown(container.dispose);

    final day = await container.read(dietTodayProvider.future);
    expect(day, isA<DietDay>());
    // 오늘 저녁은 데모 시연을 위해 비워 둔다 (#548).
    expect(day.entries.length, 3);
    expect(
      day.entries.map((DietEntry e) => e.mealType),
      containsAll(<MealType>[
        MealType.breakfast,
        MealType.lunch,
        MealType.snack,
      ]),
    );
    expect(
      day.entries.map((DietEntry e) => e.mealType),
      isNot(contains(MealType.dinner)),
    );
    expect(day.totalCalories, 1067);
    expect(day.totalSodiumMg, 3428);
    expect(day.macros.carbsG, closeTo(120.0, 0.001));
    expect(day.macros.proteinG, closeTo(45.0, 0.001));
    expect(day.macros.fatG, closeTo(45.0, 0.001));
    expect(day.aiCoachMessage, isNotEmpty);
  });

  test('dietByDateProvider keeps dates as separate keys', () async {
    final repository = _DateRecordingDietRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        dietRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final firstDate = DateTime(2026, 8, 2);
    final secondDate = DateTime(2026, 8, 3);

    final first = await container.read(dietByDateProvider(firstDate).future);
    final second = await container.read(dietByDateProvider(secondDate).future);

    expect(first.totalCalories, 2);
    expect(second.totalCalories, 3);
    expect(repository.requestedDates, <DateTime>[firstDate, secondDate]);
  });

  test(
    'dietByDateProvider shares one key for times on the same date',
    () async {
      final repository = _DateRecordingDietRepository();
      final container = ProviderContainer(
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final morning = dietByDateProvider(DateTime(2026, 8, 2, 8));
      final evening = dietByDateProvider(DateTime(2026, 8, 2, 20));

      await container.read(morning.future);
      await container.read(evening.future);
      expect(repository.requestedDates, <DateTime>[DateTime(2026, 8, 2)]);
    },
  );
}

class _DateRecordingDietRepository extends FakeDietRepository {
  final List<DateTime> requestedDates = <DateTime>[];

  @override
  Future<DietDay> fetchByDate(DateTime date) async {
    requestedDates.add(date);
    return DietDay(
      entries: const <DietEntry>[],
      totalCalories: date.day,
      totalSodiumMg: 0,
      totalSugarG: 0,
      macros: const DietMacros.zero(),
      aiCoachMessage: '',
    );
  }
}
