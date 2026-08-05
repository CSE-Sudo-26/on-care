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

  test('정수 값으로 들어온 당류도 double 로 읽힌다', () async {
    // 서버나 시드가 정수를 그대로 보내는 경우. (이 테이블은 이미 REAL 이므로
    // v5 업그레이드 경로 자체는 아래 친화도 테스트가 따로 덮는다.)
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

  test('v5 시절 INTEGER 컬럼도 소수를 보존한다 (테이블 재생성을 생략한 근거)', () async {
    // v6 마이그레이션은 DDL 없이 스키마 버전만 올린다. 그 근거가 "SQLite 의
    // INTEGER 친화도는 무손실일 때만 정수로 변환한다" 인데, 이 가정이 깨지면
    // 기존 설치에서 8.5 가 8 로 잘린다. 구형 스키마를 그대로 만들어 확인한다.
    await db.customStatement(
      'CREATE TABLE legacy_diet_entries (id TEXT PRIMARY KEY, sugar_g INTEGER)',
    );
    await db.customStatement(
      "INSERT INTO legacy_diet_entries VALUES ('a', 8.5), ('b', 8)",
    );

    final rows = await db
        .customSelect(
          'SELECT id, sugar_g, typeof(sugar_g) AS t '
          'FROM legacy_diet_entries ORDER BY id',
        )
        .get();

    // 8.5 는 정수로 무손실 변환이 안 되므로 REAL 로 남는다.
    expect(rows[0].read<double>('sugar_g'), 8.5);
    expect(rows[0].read<String>('t'), 'real');
    // 8 은 정수로 저장되지만 double 로 읽어도 손실이 없다.
    expect(rows[1].read<double>('sugar_g'), 8.0);
    expect(rows[1].read<String>('t'), 'integer');
  });
}
