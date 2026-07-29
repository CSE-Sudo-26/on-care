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
      expect(before.entries.length, 2);
      expect(before.totalCalories, 967);
      expect(before.totalSodiumMg, 3421);
      expect(before.totalSugarG, closeTo(14.8, 0.001));

      final result = await repo.analyze(
        imageBytes: bytes,
        filename: 'dinner.jpg',
        mealType: 'dinner',
        idempotencyKey: 'k1',
      );

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 3);
      expect(after.entries.map((DietEntry e) => e.id), contains(result.entryId));
      expect(after.entries.last.mealType, MealType.dinner);
      expect(after.totalCalories, 1582); // 967 + 615
      expect(after.totalSodiumMg, 4621); // 3421 + 1200
      expect(after.totalSugarG, closeTo(23.8, 0.001)); // 14.8 + 9
    });

    test('analyze is idempotent on a repeated key (no duplicate entry)', () async {
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
      expect(after.entries.length, 3); // 2 seeded + 1 (중복 없음)
      expect(after.totalCalories, 1582);
    });

    test('deleteEntry removes it and restores the totals', () async {
      final repo = MockDietRepository();
      final result = await repo.analyze(
        imageBytes: bytes,
        filename: 'a.jpg',
        mealType: 'snack',
        idempotencyKey: 'k2',
      );
      expect((await repo.fetchToday()).entries.length, 3);

      await repo.deleteEntry(result.entryId);

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 2);
      expect(after.totalCalories, 967);
      expect(after.totalSodiumMg, 3421);
      expect(after.totalSugarG, closeTo(14.8, 0.001));
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
        expect((await repo.fetchToday()).entries.length, 3);

        // 항목 삭제 → 멱등 캐시도 함께 정리돼야 한다.
        await repo.deleteEntry(first.entryId);
        expect((await repo.fetchToday()).entries.length, 2);

        // 같은 키로 재요청하면 (낡은 결과만 반환하는 대신) 다시 추가된다.
        final second = await repo.analyze(
          imageBytes: bytes,
          filename: 'a.jpg',
          mealType: 'dinner',
          idempotencyKey: 'reuse',
        );
        final DietDay after = await repo.fetchToday();
        expect(after.entries.length, 3);
        expect(
          after.entries.map((DietEntry e) => e.id),
          contains(second.entryId),
        );
        expect(after.totalCalories, 1582); // 967 + 615 다시 반영
      },
    );

    test('updateEntry edits a seeded entry and re-derives totals', () async {
      final repo = MockDietRepository();
      await repo.updateEntry(
        id: 'mock-lunch',
        totalCalories: 500, // 750 → 500
        sodiumMg: 1000, // 3200 → 1000
        sugarG: 4, // 8.5 → 4
      );

      final DietDay after = await repo.fetchToday();
      expect(after.entries.length, 2);
      expect(after.totalCalories, 717); // 967 - 750 + 500
      expect(after.totalSodiumMg, 1221); // 3421 - 3200 + 1000
      expect(after.totalSugarG, closeTo(10.3, 0.001)); // 14.8 - 8.5 + 4
    });
  });
}
