import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/storage/seed_data.dart';

String _todayString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('seedIfEmpty', () {
    test('first run seeds diet/exercise/schedule with today\'s date', () async {
      await seedIfEmpty(db);

      final today = _todayString();
      final diet = await db.select(db.dietEntries).get();
      final sched = await db.select(db.scheduleEvents).get();
      final exercise = await db.select(db.exerciseSessions).get();

      expect(diet, isNotEmpty);
      expect(
        diet.every((r) => r.date == today),
        isTrue,
        reason: 'all seeded diet rows must use today\'s date',
      );
      // Schedule seeds a couple of events on today (for the dashboard's
      // "오늘의 일정") plus a few spread across the current month (for the
      // calendar). All stay within the current month so the date-slide
      // keeps them visible.
      final ym = today.substring(0, 7);
      expect(sched, isNotEmpty);
      expect(
        sched.every((r) => r.date.startsWith('$ym-')),
        isTrue,
        reason: 'all seeded schedule rows must be in the current month',
      );
      expect(
        sched.any((r) => r.date == today),
        isTrue,
        reason: 'at least one schedule row must be on today',
      );
      expect(
        exercise,
        isNotEmpty,
        reason: 'exercise sessions for the current week must be seeded',
      );

      expect(await db.readValue('seeded_v4'), today);
    });

    test('same-day re-run is a no-op (does not duplicate rows)', () async {
      await seedIfEmpty(db);
      final dietBefore = await db.select(db.dietEntries).get();
      final exerciseBefore = await db.select(db.exerciseSessions).get();

      await seedIfEmpty(db);
      final dietAfter = await db.select(db.dietEntries).get();
      final exerciseAfter = await db.select(db.exerciseSessions).get();

      expect(dietAfter.length, dietBefore.length);
      expect(exerciseAfter.length, exerciseBefore.length);
    });

    test('diet seed has consistent realistic nutrition totals', () async {
      await seedIfEmpty(db);
      final diet = await db.select(db.dietEntries).get();

      expect(diet.length, 3);
      expect(
        diet.fold<int>(0, (sum, entry) => sum + entry.totalCalories),
        1067,
      );
      expect(diet.fold<int>(0, (sum, entry) => sum + entry.sodiumMg), 3428);

      for (final entry in diet) {
        final foods = (jsonDecode(entry.foodsJson) as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(
          foods.fold<int>(
            0,
            (sum, food) => sum + (food['calories']! as num).toInt(),
          ),
          entry.totalCalories,
        );
        expect(
          foods.fold<int>(
            0,
            (sum, food) => sum + (food['sodium_mg']! as num).toInt(),
          ),
          entry.sodiumMg,
        );
      }
    });

    test('stale flag (different date) re-seeds with today', () async {
      // Pretend the seed last ran a week ago.
      await seedIfEmpty(db);
      await db.putValue('seeded_v4', '2020-01-01');

      await seedIfEmpty(db);

      final today = _todayString();
      final diet = await db.select(db.dietEntries).get();
      expect(diet, isNotEmpty);
      expect(
        diet.every((r) => r.date == today),
        isTrue,
        reason: 're-seed must overwrite stale dates with today',
      );
      expect(await db.readValue('seeded_v4'), today);
    });

    test('legacy seeded_v2=true flag is migrated and cleared', () async {
      // Simulate a user upgrading from the v2-flag schema. The legacy
      // flag was a boolean string and locked all seed rows to the
      // first-boot date forever.
      await db.putValue('seeded_v2', 'true');
      await db
          .into(db.dietEntries)
          .insert(
            DietEntriesCompanion.insert(
              id: 'seed-diet-stale',
              date: '2024-01-01',
              mealType: 'breakfast',
              timeLabel: '08:00',
              foodsJson: '[]',
              totalCalories: 0,
              sodiumMg: const Value(0),
              sugarG: const Value(0),
            ),
          );

      await seedIfEmpty(db);

      // Legacy flag cleared, v3 flag set to today.
      expect(await db.readValue('seeded_v2'), isNull);
      expect(await db.readValue('seeded_v4'), _todayString());

      // Stale seed-prefixed row was wiped and replaced with today's
      // seed batch.
      final diet = await db.select(db.dietEntries).get();
      expect(
        diet.any((r) => r.id == 'seed-diet-stale'),
        isFalse,
        reason: 'stale v2 seed rows must be wiped on v3 migration',
      );
      expect(diet.every((r) => r.date == _todayString()), isTrue);
    });

    test('user-added (non-seed) rows survive a re-seed', () async {
      // First boot: drop a row the user "entered" directly.
      await db
          .into(db.vitals)
          .insert(
            VitalsCompanion.insert(
              id: 'user-vital-1',
              kind: 'weight',
              valueJson: '{"kg":72.5}',
              recordedAt: DateTime.now(),
            ),
          );

      await seedIfEmpty(db);
      // Force a re-seed by ageing the flag.
      await db.putValue('seeded_v4', '2020-01-01');
      await seedIfEmpty(db);

      final vitals = await db.select(db.vitals).get();
      expect(
        vitals.any((r) => r.id == 'user-vital-1'),
        isTrue,
        reason: 'rows without a seed- prefix must never be touched',
      );
    });
  });
}
