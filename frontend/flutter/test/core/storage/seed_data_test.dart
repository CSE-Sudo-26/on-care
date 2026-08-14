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

String _daysAgoString(int days) {
  final date = DateTime.now().subtract(Duration(days: days));
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
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
      expect(diet.where((r) => r.date == today).length, 3);
      expect(diet.where((r) => r.date == _daysAgoString(1)).length, 3);
      expect(diet.where((r) => r.date == _daysAgoString(2)).length, 3);
      // 큐레이션 사흘 앞으로도 기록이 이어진다 — 날짜를 옮기면 대부분
      // 비어 있던 데모 문제(#671).
      expect(diet.where((r) => r.date == _daysAgoString(3)), isNotEmpty);
      expect(diet.where((r) => r.date == _daysAgoString(30)), isNotEmpty);
      expect(
        diet.where((r) => r.date == _daysAgoString(kDemoDietHistoryDays + 5)),
        isEmpty,
        reason: '히스토리는 한 달치까지만 채운다',
      );
      final salmonDinner = diet.firstWhere(
        (row) => row.id == 'seed-diet-two-days-ago-dinner',
      );
      final salmonDinnerFoods =
          (jsonDecode(salmonDinner.foodsJson) as List<Object?>)
              .cast<Map<String, Object?>>();
      expect(salmonDinnerFoods.map((food) => food['name']), <String>[
        '연어구이',
        '현미밥',
      ]);
      // 지난 이틀은 하루가 끝난 기록이라 저녁까지 있고, 오늘은 저녁을 비워 둔다
      // — 데모에서 사진으로 저녁을 기록하는 흐름을 위해서다 (#548).
      for (final date in <String>[_daysAgoString(1), _daysAgoString(2)]) {
        final mealTypes = diet
            .where((row) => row.date == date)
            .map((row) => row.mealType)
            .toSet();
        expect(
          mealTypes,
          containsAll(<String>['breakfast', 'lunch', 'dinner']),
        );
      }
      expect(
        diet
            .where((row) => row.date == today)
            .map((row) => row.mealType)
            .toSet(),
        <String>{'breakfast', 'lunch', 'snack'},
      );
      // 큐레이션 사흘 중 간식은 오늘 하루뿐이다(과거 히스토리는 별도).
      expect(
        diet
            .where(
              (row) =>
                  row.mealType == 'snack' &&
                  <String>[
                    today,
                    _daysAgoString(1),
                    _daysAgoString(2),
                  ].contains(row.date),
            )
            .length,
        1,
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

      expect(await db.readValue('seeded_v15'), today);
    });

    test('과거 식단은 날짜마다 값이 달라 추이가 직선이 되지 않는다', () async {
      await seedIfEmpty(db);
      final diet = await db.select(db.dietEntries).get();

      final Map<String, int> caloriesByDate = <String, int>{};
      for (int offset = 3; offset < 3 + kDemoDietHistoryDays; offset++) {
        final String date = _daysAgoString(offset);
        final int kcal = diet
            .where((r) => r.date == date)
            .fold<int>(0, (int sum, r) => sum + r.totalCalories);
        if (kcal > 0) caloriesByDate[date] = kcal;
      }

      expect(caloriesByDate.length, greaterThan(20));
      expect(
        caloriesByDate.values.toSet().length,
        greaterThan(3),
        reason: '모든 날이 같은 칼로리면 주간·월간 추이가 직선이 된다',
      );
      // 기록이 통째로 없는 날도 남겨 둔다 — 빈 화면이 맞게 동작하는지 데모에서
      // 볼 수 있어야 한다.
      expect(
        caloriesByDate.length,
        lessThan(kDemoDietHistoryDays),
        reason: '기록 없는 날이 최소 하나는 남아야 한다',
      );
    });

    test('지난 주 운동 세션도 시드된다', () async {
      await seedIfEmpty(db);
      final exercise = await db.select(db.exerciseSessions).get();

      final DateTime now = DateTime.now();
      final DateTime thisMonday = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1),
      );
      final Set<String> weekStarts = exercise.map((r) => r.weekStart).toSet();

      for (
        int weeksAgo = 0;
        weeksAgo <= kDemoExerciseHistoryWeeks;
        weeksAgo++
      ) {
        final DateTime monday = thisMonday.subtract(
          Duration(days: 7 * weeksAgo),
        );
        final String key =
            '${monday.year.toString().padLeft(4, '0')}-'
            '${monday.month.toString().padLeft(2, '0')}-'
            '${monday.day.toString().padLeft(2, '0')}';
        expect(weekStarts, contains(key), reason: '$weeksAgo주 전 운동 기록이 있어야 한다');
      }
    });

    test('큐레이션 아홉 행의 표현(시각·코치 문구·사진)이 그대로 남는다', () async {
      // 수치를 템플릿 한 곳으로 모으면서(#677) 데모 화면의 문구·사진·시각이
      // 바뀌면 안 된다. 합계는 다른 테스트가 보므로 여기서는 표현만 못박는다.
      // 세 필드를 아홉 행 모두 검증한다 — 일부만 보면 나머지가 조용히 바뀐다.
      await seedIfEmpty(db);
      final diet = await db.select(db.dietEntries).get();
      DietEntryRow row(String id) => diet.firstWhere((r) => r.id == id);

      const Map<String, (String time, String comment, String photo)> expected =
          <String, (String, String, String)>{
            'seed-diet-breakfast': (
              '08:20',
              '단백질과 식이섬유의 깔끔한 조합으로, 소금 간과 기름만 조절하면 혈당과 혈압 모두 잡는 우수한 식단입니다.',
              'assets/images/breakfast-scrambled-egg-strawberry.jpg',
            ),
            'seed-diet-lunch': (
              '12:40',
              '정제 면과 높은 나트륨으로 혈압·혈당 부담이 매우 크니, 국물은 남기고 야채 위주로 드시는 것이 좋습니다.',
              'assets/images/lunch-jjamppong.jpg',
            ),
            'seed-diet-snack': (
              '15:30',
              '당류와 칼로리가 낮고 견과류의 건강한 지방이 채워져 완벽한 간식입니다.',
              'assets/images/snack-coffee-nuts.jpg',
            ),
            'seed-diet-yesterday-breakfast': (
              '08:10',
              '오트밀로 식이섬유를 챙겼어요. 바나나가 들어가 당류는 다소 높은 편이에요.',
              'assets/images/diet-oatmeal-banana.jpeg',
            ),
            'seed-diet-yesterday-lunch': (
              '12:30',
              '닭가슴살과 채소로 단백질과 식이섬유를 고르게 섭취했어요.',
              'assets/images/diet-chicken-salad.jpg',
            ),
            'seed-diet-yesterday-dinner': (
              '18:45',
              '밥과 찌개를 함께 섭취해 포만감은 좋지만 국물은 조금 남기면 좋아요.',
              'assets/images/diet-doenjang-rice.jpeg',
            ),
            'seed-diet-two-days-ago-breakfast': (
              '08:35',
              '그릭 요거트의 단백질과 견과류의 불포화지방을 고르게 섭취했어요.',
              'assets/images/diet-greek-yogurt-nuts.jpeg',
            ),
            'seed-diet-two-days-ago-lunch': (
              '12:20',
              '야채가 풍부한 비빔밥이에요. 고추장을 줄이면 나트륨을 더 조절할 수 있어요.',
              'assets/images/diet-vegetable-bibimbap.jpg',
            ),
            'seed-diet-two-days-ago-dinner': (
              '18:50',
              '연어의 지방과 현미밥의 복합 탄수화물 조합이 좋아요.',
              'assets/images/diet-salmon-brown-rice.jpeg',
            ),
          };

      for (final MapEntry<String, (String, String, String)> e
          in expected.entries) {
        final DietEntryRow r = row(e.key);
        expect(r.timeLabel, e.value.$1, reason: '${e.key} 시각');
        expect(r.aiComment, e.value.$2, reason: '${e.key} 코치 문구');
        expect(r.photoAsset, e.value.$3, reason: '${e.key} 사진');
      }
    });

    test('큐레이션 사흘의 행 id 는 고정이다', () async {
      // companion() 의 id 는 선택 인자다. 큐레이션 호출에서 빠뜨리면
      // `seed-diet-2026-08-14-lunch` 같은 날짜 id 로 조용히 바뀌는데, 화면과
      // 테스트가 이 리터럴 id 로 행을 찾는다.
      await seedIfEmpty(db);
      final diet = await db.select(db.dietEntries).get();
      final Set<String> ids = diet.map((r) => r.id).toSet();

      expect(
        ids,
        containsAll(<String>[
          'seed-diet-breakfast',
          'seed-diet-lunch',
          'seed-diet-snack',
          'seed-diet-yesterday-breakfast',
          'seed-diet-yesterday-lunch',
          'seed-diet-yesterday-dinner',
          'seed-diet-two-days-ago-breakfast',
          'seed-diet-two-days-ago-lunch',
          'seed-diet-two-days-ago-dinner',
        ]),
      );
      // 큐레이션 사흘이 날짜 id 로 새어 나가지 않았는지.
      for (final String date in <String>[
        _todayString(),
        _daysAgoString(1),
        _daysAgoString(2),
      ]) {
        expect(
          ids.where((String id) => id.startsWith('seed-diet-$date-')),
          isEmpty,
          reason: '$date 의 큐레이션 행이 날짜 id 로 만들어졌다',
        );
      }
    });

    test('같은 음식은 어느 날짜에 쓰이든 영양 수치가 하나다', () async {
      // #677 이 없애려는 상태: 큐레이션 쪽과 히스토리 쪽에 같은 음식의 수치가
      // 두 벌 존재해, 한쪽만 고치면 조용히 갈린다.
      await seedIfEmpty(db);
      final diet = await db.select(db.dietEntries).get();

      final Map<String, Set<String>> fingerprintsByFood =
          <String, Set<String>>{};
      final Map<String, Set<String>> datesByFood = <String, Set<String>>{};
      for (final row in diet) {
        for (final food
            in (jsonDecode(row.foodsJson) as List<Object?>)
                .cast<Map<String, Object?>>()) {
          final String name = food['name']! as String;
          // 이름을 뺀 나머지(칼로리·나트륨·당류·탄단지)를 지문으로 삼는다.
          final Map<String, Object?> rest = Map<String, Object?>.of(food)
            ..remove('name');
          (fingerprintsByFood[name] ??= <String>{}).add(jsonEncode(rest));
          (datesByFood[name] ??= <String>{}).add(row.date);
        }
      }

      final List<String> conflicting = <String>[
        for (final entry in fingerprintsByFood.entries)
          if (entry.value.length > 1) entry.key,
      ];
      expect(
        conflicting,
        isEmpty,
        reason: '같은 음식이 서로 다른 영양 수치로 시드됐다: $conflicting',
      );

      // 여러 날짜에 실제로 재사용되는 음식이 있어야 위 검증이 뜻을 갖는다.
      // 존재 여부만 보면 재사용이 사라져도 통과한다(CodeRabbit).
      final List<String> reused = <String>[
        for (final entry in datesByFood.entries)
          if (entry.value.length > 1) entry.key,
      ];
      expect(
        reused,
        isNotEmpty,
        reason: '여러 날짜에 쓰이는 음식이 없으면 이 검증이 아무것도 지키지 못한다',
      );
      expect(
        datesByFood['짬뽕']?.length ?? 0,
        greaterThan(1),
        reason: '짬뽕은 오늘(큐레이션)과 히스토리 양쪽에 쓰인다',
      );
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
      final allDiet = await db.select(db.dietEntries).get();
      final diet = allDiet
          .where((entry) => entry.date == _todayString())
          .toList();

      // 오늘은 아침·점심·간식 셋뿐이다 — 저녁은 데모 시연을 위해 비워 둔다 (#548).
      expect(diet.length, 3);
      expect(diet.every((entry) => entry.mealType != 'dinner'), isTrue);
      expect(
        diet.fold<int>(0, (sum, entry) => sum + entry.totalCalories),
        1067,
      );
      expect(diet.fold<int>(0, (sum, entry) => sum + entry.sodiumMg), 3428);
      expect(
        diet.fold<double>(0, (sum, entry) => sum + entry.sugarG),
        closeTo(17.8, 0.001),
      );

      for (final entry in allDiet) {
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
        expect(
          foods.fold<double>(
            0,
            (sum, food) => sum + (food['sugar_g']! as num).toDouble(),
          ),
          closeTo(entry.sugarG, 0.001),
        );
      }
    });

    test('stale flag (different date) re-seeds with today', () async {
      // Pretend the seed last ran a week ago.
      await seedIfEmpty(db);
      await db.putValue('seeded_v15', '2020-01-01');

      await seedIfEmpty(db);

      final today = _todayString();
      final diet = await db.select(db.dietEntries).get();
      expect(diet, isNotEmpty);
      expect(diet.where((r) => r.date == today).length, 3);
      expect(await db.readValue('seeded_v15'), today);
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

      // Legacy flag cleared, current flag set to today.
      expect(await db.readValue('seeded_v2'), isNull);
      expect(await db.readValue('seeded_v15'), _todayString());

      // Stale seed-prefixed row was wiped and replaced with today's
      // seed batch.
      final diet = await db.select(db.dietEntries).get();
      expect(
        diet.any((r) => r.id == 'seed-diet-stale'),
        isFalse,
        reason: 'stale v2 seed rows must be wiped during migration',
      );
      expect(diet.where((r) => r.date == _todayString()).length, 3);
    });

    test('user-added (non-seed) rows survive a re-seed', () async {
      // First boot: drop a row the user "entered" directly.
      await db
          .into(db.dietEntries)
          .insert(
            DietEntriesCompanion.insert(
              id: 'user-diet-1',
              date: _todayString(),
              mealType: 'lunch',
              timeLabel: '12:00',
              foodsJson: '[]',
              totalCalories: 300,
            ),
          );

      await seedIfEmpty(db);
      // Force a re-seed by ageing the flag.
      await db.putValue('seeded_v15', '2020-01-01');
      await seedIfEmpty(db);

      final diet = await db.select(db.dietEntries).get();
      expect(
        diet.any((r) => r.id == 'user-diet-1'),
        isTrue,
        reason: 'rows without a seed- prefix must never be touched',
      );
    });
  });
}
