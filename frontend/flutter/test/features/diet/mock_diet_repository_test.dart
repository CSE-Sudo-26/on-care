import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';

void main() {
  final Uint8List bytes = Uint8List(0);

  group('MockDietRepository keeps CRUD in memory (#294)', () {
    test('analyze appends an entry and updates the day totals', () async {
      final repo = MockDietRepository();
      final DietDay before = await repo.fetchToday();
      expect(before.entries.length, 4);
      expect(before.totalCalories, 1860);
      expect(before.totalSodiumMg, 2329);
      expect(before.totalSugarG, closeTo(43, 0.001));

      final result = await repo.analyze(
        imageBytes: bytes,
        filename: 'dinner.jpg',
        mealType: 'dinner',
        idempotencyKey: 'k1',
      );

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 5);
      expect(
        after.entries.map((DietEntry e) => e.id),
        contains(result.entryId),
      );
      expect(after.entries.last.mealType, MealType.dinner);
      expect(after.totalCalories, 2475); // 1860 + 615
      expect(after.totalSodiumMg, 3529); // 2329 + 1200
      expect(after.totalSugarG, closeTo(52, 0.001)); // 43 + 9
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
        expect(after.entries.length, 5); // 4 seeded + 1 (중복 없음)
        expect(after.totalCalories, 2475);
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
      expect((await repo.fetchToday()).entries.length, 5);

      await repo.deleteEntry(result.entryId);

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 4);
      expect(after.totalCalories, 1860);
      expect(after.totalSodiumMg, 2329);
      expect(after.totalSugarG, closeTo(43, 0.001));
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
        expect((await repo.fetchToday()).entries.length, 5);

        // 항목 삭제 → 멱등 캐시도 함께 정리돼야 한다.
        await repo.deleteEntry(first.entryId);
        expect((await repo.fetchToday()).entries.length, 4);

        // 같은 키로 재요청하면 (낡은 결과만 반환하는 대신) 다시 추가된다.
        final second = await repo.analyze(
          imageBytes: bytes,
          filename: 'a.jpg',
          mealType: 'dinner',
          idempotencyKey: 'reuse',
        );
        final DietDay after = await repo.fetchToday();
        expect(after.entries.length, 5);
        expect(
          after.entries.map((DietEntry e) => e.id),
          contains(second.entryId),
        );
        expect(after.totalCalories, 2475); // 1860 + 615 다시 반영
      },
    );

    test('updateEntry edits a seeded entry and re-derives totals', () async {
      final repo = MockDietRepository();
      await repo.updateEntry(
        id: 'mock-lunch',
        totalCalories: 500, // 780 → 500
        sodiumMg: 1000, // 1643 → 1000
        sugarG: 4, // 7 → 4
      );

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 4);
      expect(after.totalCalories, 1580); // 1860 - 780 + 500
      expect(after.totalSodiumMg, 1686); // 2329 - 1643 + 1000
      expect(after.totalSugarG, closeTo(40, 0.001)); // 43 - 7 + 4
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

  test('kimchi stew and kimchi are the largest sodium sources', () async {
    final day = await MockDietRepository().fetchToday();
    final foods = day.entries.expand((DietEntry entry) => entry.foods).toList()
      ..sort((FoodItem a, FoodItem b) => b.sodiumMg.compareTo(a.sodiumMg));

    expect(foods.take(2).map((FoodItem food) => food.name), <String>[
      '김치찌개',
      '배추김치',
    ]);
    expect(day.aiCoachMessage, contains('김치찌개와 배추김치'));
    expect(day.totalSodiumMg, greaterThan(2000));
  });
}
