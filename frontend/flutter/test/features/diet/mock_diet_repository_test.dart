import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';

void main() {
  final Uint8List bytes = Uint8List(0);

  group('MockDietRepository keeps CRUD in memory (#294)', () {
    test(
      'fetchByDate returns seeded history and keeps an older date empty',
      () async {
        final repo = MockDietRepository();
        final now = DateTime.now();

        final today = await repo.fetchByDate(now);
        // 오늘 저녁은 데모 시연(사진으로 저녁 기록)을 위해 비워 둔다 (#548).
        expect(today.entries.length, 3);
        expect(
          today.entries.map((entry) => entry.mealType),
          isNot(contains(MealType.dinner)),
        );
        final yesterday = await repo.fetchByDate(
          now.subtract(const Duration(days: 1)),
        );
        expect(yesterday.entries.length, 3);
        expect(yesterday.totalCalories, 1280);
        expect(
          yesterday.entries
              .firstWhere((entry) => entry.mealType == MealType.lunch)
              .foods
              .map((food) => food.name),
          <String>['닭가슴살 샐러드'],
        );
        final twoDaysAgo = await repo.fetchByDate(
          now.subtract(const Duration(days: 2)),
        );
        final salmonDinner = twoDaysAgo.entries.firstWhere(
          (entry) => entry.mealType == MealType.dinner,
        );
        expect(
          twoDaysAgo.entries
              .firstWhere((entry) => entry.mealType == MealType.lunch)
              .foods
              .map((food) => food.name),
          <String>['야채비빔밥'],
        );
        expect(salmonDinner.foods.map((food) => food.name), <String>[
          '연어구이',
          '현미밥',
        ]);
        expect(
          salmonDinner.foods.fold<int>(0, (sum, food) => sum + food.calories),
          salmonDinner.totalCalories,
        );
        // 지난 이틀은 저녁까지 있는 완결된 하루, 오늘은 저녁을 비워 둔다 (#548).
        for (final day in <DietDay>[yesterday, twoDaysAgo]) {
          expect(
            day.entries.map((entry) => entry.mealType).toSet(),
            containsAll(<MealType>[
              MealType.breakfast,
              MealType.lunch,
              MealType.dinner,
            ]),
          );
        }
        final DietDay todayAgain = await repo.fetchByDate(now);
        expect(
          todayAgain.entries.map((entry) => entry.mealType).toSet(),
          <MealType>{MealType.breakfast, MealType.lunch, MealType.snack},
        );
        expect(
          <DietDay>[await repo.fetchByDate(now), yesterday, twoDaysAgo]
              .expand((day) => day.entries)
              .where((entry) => entry.mealType == MealType.snack),
          hasLength(1),
        );
        expect(
          (await repo.fetchByDate(
            now.subtract(const Duration(days: 3)),
          )).entries,
          isEmpty,
        );
      },
    );

    test('analyze appends an entry and updates the day totals', () async {
      final repo = MockDietRepository();
      final DietDay before = await repo.fetchToday();
      expect(before.entries.length, 3);
      expect(before.totalCalories, 1067);
      expect(before.totalSodiumMg, 3428);
      expect(before.totalSugarG, closeTo(17.8, 0.001));

      final result = await repo.analyze(
        imageBytes: bytes,
        filename: 'dinner.jpg',
        mealType: 'dinner',
        idempotencyKey: 'k1',
      );

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 4);
      expect(
        after.entries.map((DietEntry e) => e.id),
        contains(result.entryId),
      );
      expect(after.entries.last.mealType, MealType.dinner);
      expect(after.totalCalories, 1682); // 1067 + 615
      expect(after.totalSodiumMg, 4628); // 3428 + 1200
      expect(after.totalSugarG, closeTo(26.8, 0.001)); // 17.8 + 9
      _expectMacrosMatchEntries(after);
    });

    test(
      'analyze is idempotent on a repeated key (no duplicate entry)',
      () async {
        final repo = MockDietRepository();
        final first = await repo.analyze(
          imageBytes: bytes,
          filename: 'a.jpg',
          mealType: 'dinner',
          idempotencyKey: 'same',
        );
        final second = await repo.analyze(
          imageBytes: bytes,
          filename: 'a.jpg',
          mealType: 'dinner',
          idempotencyKey: 'same',
        );

        expect(second.entryId, first.entryId);
        final DietDay after = await repo.fetchToday();
        expect(after.entries.length, 4); // 3 seeded + 1 (중복 없음)
        expect(after.totalCalories, 1682);
      },
    );

    test('deleteEntry removes it and restores the totals', () async {
      final repo = MockDietRepository();
      final result = await repo.analyze(
        imageBytes: bytes,
        filename: 'a.jpg',
        mealType: 'snack',
        idempotencyKey: 'k2',
      );
      expect((await repo.fetchToday()).entries.length, 4);

      await repo.deleteEntry(result.entryId);

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 3);
      expect(after.totalCalories, 1067);
      expect(after.totalSodiumMg, 3428);
      expect(after.totalSugarG, closeTo(17.8, 0.001));
    });

    test(
      'same key after delete re-adds the entry (cache purged on delete, 리뷰 #294)',
      () async {
        final repo = MockDietRepository();
        final first = await repo.analyze(
          imageBytes: bytes,
          filename: 'a.jpg',
          mealType: 'dinner',
          idempotencyKey: 'reuse',
        );
        expect((await repo.fetchToday()).entries.length, 4);

        // 항목 삭제 → 멱등 캐시도 함께 정리돼야 한다.
        await repo.deleteEntry(first.entryId);
        expect((await repo.fetchToday()).entries.length, 3);

        // 같은 키로 재요청하면 (낡은 결과만 반환하는 대신) 다시 추가된다.
        final second = await repo.analyze(
          imageBytes: bytes,
          filename: 'a.jpg',
          mealType: 'dinner',
          idempotencyKey: 'reuse',
        );
        final DietDay after = await repo.fetchToday();
        expect(after.entries.length, 4);
        expect(
          after.entries.map((DietEntry e) => e.id),
          contains(second.entryId),
        );
        expect(after.totalCalories, 1682); // 1067 + 615 다시 반영
      },
    );

    test('updateEntry re-derives day totals and macros', () async {
      final repo = MockDietRepository();
      await repo.updateEntry(
        id: 'mock-lunch',
        foods: const <FoodItem>[
          FoodItem(
            name: '수정된 점심',
            calories: 500,
            carbsG: 10,
            proteinG: 20,
            fatG: 5,
          ),
        ],
        totalCalories: 500, // 750 → 500
        sodiumMg: 1000, // 3200 → 1000
        sugarG: 4, // 8.5 → 4
      );

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 3);
      expect(after.totalCalories, 817); // 1067 - 750 + 500
      expect(after.totalSodiumMg, 1228); // 3428 - 3200 + 1000
      expect(after.totalSugarG, closeTo(13.3, 0.001)); // 17.8 - 8.5 + 4
      // 아침 + 간식 + 수정된 점심의 합계.
      expect(after.macros.carbsG, closeTo(23, 0.001));
      expect(after.macros.proteinG, closeTo(36, 0.001));
      expect(after.macros.fatG, closeTo(27.5, 0.001));
      expect(
        <int>[
          after.macros.carbsPct,
          after.macros.proteinPct,
          after.macros.fatPct,
        ],
        <int>[19, 30, 51],
      );
      _expectMacrosMatchEntries(after);
    });

    test('deleteEntry re-derives day macros from remaining entries', () async {
      final repo = MockDietRepository();

      await repo.deleteEntry('mock-lunch');

      final DietDay after = await repo.fetchToday();
      // 점심(짬뽕) 삭제 → 아침 + 간식만 남는다.
      expect(after.macros.carbsG, closeTo(13, 0.001));
      expect(after.macros.proteinG, closeTo(16, 0.001));
      expect(after.macros.fatG, closeTo(22.5, 0.001));
      expect(
        <int>[
          after.macros.carbsPct,
          after.macros.proteinPct,
          after.macros.fatPct,
        ],
        <int>[16, 20, 64],
      );
      _expectMacrosMatchEntries(after);
    });

    test('empty entries return zero macros without throwing', () async {
      final repo = MockDietRepository();
      final DietDay before = await repo.fetchToday();

      for (final entry in before.entries) {
        await repo.deleteEntry(entry.id!);
      }

      final DietDay after = await repo.fetchToday();
      expect(after.entries, isEmpty);
      expect(after.macros.carbsG, 0);
      expect(after.macros.proteinG, 0);
      expect(after.macros.fatG, 0);
      expect(after.macros.carbsPct, 0);
      expect(after.macros.proteinPct, 0);
      expect(after.macros.fatPct, 0);
    });
  });

  test(
    'realistic seed keeps food, meal and daily nutrition totals aligned',
    () async {
      final day = await MockDietRepository().fetchToday();

      for (final entry in day.entries) {
        expect(
          entry.foods.fold<int>(
            0,
            (int sum, FoodItem food) => sum + food.calories,
          ),
          entry.totalCalories,
        );
        expect(
          entry.foods.fold<int>(
            0,
            (int sum, FoodItem food) => sum + food.sodiumMg,
          ),
          entry.sodiumMg,
        );
        expect(
          entry.foods.fold<double>(
            0,
            (double sum, FoodItem food) => sum + food.carbsG,
          ),
          closeTo(entry.carbsG, 0.001),
        );
        expect(
          entry.foods.fold<double>(
            0,
            (double sum, FoodItem food) => sum + food.proteinG,
          ),
          closeTo(entry.proteinG, 0.001),
        );
        expect(
          entry.foods.fold<double>(
            0,
            (double sum, FoodItem food) => sum + food.fatG,
          ),
          closeTo(entry.fatG, 0.001),
        );
      }

      expect(
        day.entries.fold<int>(
          0,
          (int sum, DietEntry entry) => sum + entry.totalCalories,
        ),
        day.totalCalories,
      );
      expect(
        day.entries.fold<int>(
          0,
          (int sum, DietEntry entry) => sum + entry.sodiumMg,
        ),
        day.totalSodiumMg,
      );
      expect(
        day.entries.fold<double>(
          0,
          (double sum, DietEntry entry) => sum + entry.carbsG,
        ),
        closeTo(day.macros.carbsG, 0.001),
      );
      expect(
        day.entries.fold<double>(
          0,
          (double sum, DietEntry entry) => sum + entry.proteinG,
        ),
        closeTo(day.macros.proteinG, 0.001),
      );
      expect(
        day.entries.fold<double>(
          0,
          (double sum, DietEntry entry) => sum + entry.fatG,
        ),
        closeTo(day.macros.fatG, 0.001),
      );
      expect(
        day.macros.carbsPct + day.macros.proteinPct + day.macros.fatPct,
        100,
      );
    },
  );

  test('jjamppong is the largest sodium source', () async {
    final day = await MockDietRepository().fetchToday();
    final foods = day.entries.expand((DietEntry entry) => entry.foods).toList()
      ..sort((FoodItem a, FoodItem b) => b.sodiumMg.compareTo(a.sodiumMg));

    expect(foods.take(2).map((FoodItem food) => food.name), <String>[
      '짬뽕',
      '스크램블 에그',
    ]);
    expect(day.aiCoachMessage, contains('짬뽕'));
    expect(day.totalSodiumMg, greaterThan(2000));
  });

  test(
    'historical photo analysis keeps food and meal totals aligned',
    () async {
      final repo = MockDietRepository();
      final now = DateTime.now();
      for (final daysAgo in <int>[1, 2]) {
        final day = await repo.fetchByDate(
          now.subtract(Duration(days: daysAgo)),
        );
        for (final entry in day.entries) {
          expect(entry.photoAsset, isNotNull);
          expect(
            entry.foods.fold<int>(0, (sum, food) => sum + food.calories),
            entry.totalCalories,
          );
          expect(
            entry.foods.fold<int>(0, (sum, food) => sum + food.sodiumMg),
            entry.sodiumMg,
          );
          expect(
            entry.foods.fold<double>(0, (sum, food) => sum + food.sugarG),
            closeTo(entry.sugarG, 0.001),
          );
          expect(
            entry.foods.fold<double>(0, (sum, food) => sum + food.carbsG),
            closeTo(entry.carbsG, 0.001),
          );
          expect(
            entry.foods.fold<double>(0, (sum, food) => sum + food.proteinG),
            closeTo(entry.proteinG, 0.001),
          );
          expect(
            entry.foods.fold<double>(0, (sum, food) => sum + food.fatG),
            closeTo(entry.fatG, 0.001),
          );
        }
      }
    },
  );
}

void _expectMacrosMatchEntries(DietDay day) {
  expect(
    day.macros.carbsG,
    closeTo(
      day.entries.fold<double>(
        0,
        (double sum, DietEntry entry) => sum + entry.carbsG,
      ),
      0.001,
    ),
  );
  expect(
    day.macros.proteinG,
    closeTo(
      day.entries.fold<double>(
        0,
        (double sum, DietEntry entry) => sum + entry.proteinG,
      ),
      0.001,
    ),
  );
  expect(
    day.macros.fatG,
    closeTo(
      day.entries.fold<double>(
        0,
        (double sum, DietEntry entry) => sum + entry.fatG,
      ),
      0.001,
    ),
  );
  expect(day.macros.carbsPct + day.macros.proteinPct + day.macros.fatPct, 100);
}
