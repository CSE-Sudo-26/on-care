import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/storage/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('putValue → readValue roundtrip', () async {
    await db.putValue('locale', 'ko');
    expect(await db.readValue('locale'), 'ko');
  });

  test('deleteValue removes the entry', () async {
    await db.putValue('locale', 'ko');
    await db.deleteValue('locale');
    expect(await db.readValue('locale'), isNull);
  });

  test('putValue upserts on conflicting key', () async {
    await db.putValue('k', 'v1');
    await db.putValue('k', 'v2');
    expect(await db.readValue('k'), 'v2');
  });

  // #366 회귀: 당류가 IntColumn 이라 데모 모드에서 8.5 가 8 로 잘렸다.
  test('당류는 소수를 그대로 저장·조회한다', () async {
    await db
        .into(db.dietEntries)
        .insert(
          DietEntriesCompanion.insert(
            id: 'e1',
            date: '2026-08-05',
            mealType: 'lunch',
            timeLabel: '12:00',
            foodsJson: '[]',
            totalCalories: 600,
            sugarG: const Value(8.5),
          ),
        );

    final row = await (db.select(
      db.dietEntries,
    )..where((t) => t.id.equals('e1'))).getSingle();
    expect(row.sugarG, 8.5);
  });

  test('정수로 들어온 당류도 손실 없이 double 로 읽힌다', () async {
    // v5 이전에 저장된 기존 행을 흉내 낸다(정수 그대로 INSERT).
    await db.customStatement(
      'INSERT INTO diet_entries '
      '(id, date, meal_type, time_label, foods_json, total_calories, '
      ' sodium_mg, sugar_g, created_at) '
      "VALUES ('legacy', '2026-08-04', 'dinner', '19:00', '[]', 500, 900, 8, 0)",
    );

    final row = await (db.select(
      db.dietEntries,
    )..where((t) => t.id.equals('legacy'))).getSingle();
    expect(row.sugarG, 8.0);
  });

  test('소수 당류 합계가 절삭되지 않는다 (6.3 + 8.5 = 14.8)', () async {
    for (final (String id, double sugar) in <(String, double)>[
      ('a', 6.3),
      ('b', 8.5),
    ]) {
      await db
          .into(db.dietEntries)
          .insert(
            DietEntriesCompanion.insert(
              id: id,
              date: '2026-08-05',
              mealType: 'lunch',
              timeLabel: '12:00',
              foodsJson: '[]',
              totalCalories: 100,
              sugarG: Value(sugar),
            ),
          );
    }

    final rows = await db.select(db.dietEntries).get();
    final double total = rows.fold(0.0, (double a, r) => a + r.sugarG);
    expect(total, closeTo(14.8, 1e-9));
  });
}
