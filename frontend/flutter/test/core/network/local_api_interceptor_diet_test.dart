import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/core/network/interceptors/local_api_interceptor.dart';
import 'package:oncare/core/storage/app_database.dart';

void main() {
  late AppDatabase db;
  late Dio dio;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(LocalApiInterceptor(db, Logger(level: Level.off)));
  });

  tearDown(() async {
    await db.close();
    dio.close();
  });

  test(
    'GET /diet/days/{date} returns only that date or an empty day',
    () async {
      await db
          .into(db.dietEntries)
          .insert(
            DietEntriesCompanion.insert(
              id: 'diet-past',
              date: '2026-08-03',
              mealType: 'lunch',
              timeLabel: '12:00',
              foodsJson: jsonEncode(<Map<String, Object?>>[
                <String, Object?>{
                  'name': '과거 식사',
                  'calories': 420,
                  'carbs_g': 40.0,
                  'protein_g': 20.0,
                  'fat_g': 10.0,
                },
              ]),
              totalCalories: 420,
              sodiumMg: const Value(350),
              sugarG: const Value(7.5),
            ),
          );

      final past = await dio.get<Map<String, Object?>>('/diet/days/2026-08-03');
      final empty = await dio.get<Map<String, Object?>>(
        '/diet/days/2026-08-02',
      );

      expect(past.statusCode, 200);
      expect(past.data!['total_calories'], 420);
      expect(past.data!['ai_coach_message'], '균형 잡힌 하루였어요. 내일도 이대로 가요!');
      expect((past.data!['entries']! as List<Object?>).length, 1);
      expect(empty.statusCode, 200);
      expect(empty.data!['entries'], isEmpty);
      expect(empty.data!['total_calories'], 0);
    },
  );

  test('GET /diet/days/{date} rejects an invalid date like backend', () async {
    final response = await dio.get<Map<String, Object?>>(
      '/diet/days/not-a-date',
      options: Options(validateStatus: (status) => status == 422),
    );

    expect(response.statusCode, 422);
    expect(response.data!['detail'], isA<List<Object?>>());
  });

  test(
    'POST /diet/analyze returns an analysis and persists an entry',
    () async {
      final form = FormData.fromMap(<String, Object?>{
        'image': MultipartFile.fromBytes(<int>[
          1,
          2,
          3,
          4,
        ], filename: 'meal.jpg'),
        'meal_type': 'dinner',
      });
      final res = await dio.post<Map<String, Object?>>(
        '/diet/analyze',
        data: form,
      );
      expect(res.statusCode, 200);
      expect(res.data!['entry_id'], isNotNull);

      final analysis = res.data!['analysis']! as Map<String, Object?>;
      final foods = (analysis['foods']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(foods, isNotEmpty);
      expect(foods.first['name'], isNotNull);
      expect(analysis['total_calories'], greaterThan(0));

      // 저장돼서 오늘 식단 집계에 반영된다.
      final today = await dio.get<Map<String, Object?>>('/diet/days/today');
      expect(today.statusCode, 200);
      expect(today.data!['total_calories'], greaterThan(0));
      final entries = (today.data!['entries']! as List<Object?>);
      expect(entries, isNotEmpty);
      final entry = entries.single as Map<String, Object?>;
      expect(entry['carbs_g'], 94.0);
      expect(entry['protein_g'], 19.0);
      expect(entry['fat_g'], 18.0);
      final macros = today.data!['macros']! as Map<String, Object?>;
      expect(macros['carbs_g'], 94.0);
      expect(macros['protein_g'], 19.0);
      expect(macros['fat_g'], 18.0);
    },
  );

  test('same idempotency_key dedupes a retried /diet/analyze', () async {
    FormData buildForm() => FormData.fromMap(<String, Object?>{
      'image': MultipartFile.fromBytes(<int>[1, 2, 3, 4], filename: 'meal.jpg'),
      'meal_type': 'lunch',
      'idempotency_key': 'idem-fixed-1',
    });

    final first = await dio.post<Map<String, Object?>>(
      '/diet/analyze',
      data: buildForm(),
    );
    final String firstId = first.data!['entry_id']! as String;

    // Simulate a lost-response retry with the SAME key → same entry, no dup.
    final second = await dio.post<Map<String, Object?>>(
      '/diet/analyze',
      data: buildForm(),
    );
    expect(second.data!['entry_id'], firstId);

    final today = await dio.get<Map<String, Object?>>('/diet/days/today');
    final entries = (today.data!['entries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    // Only one row for that key.
    expect(entries.where((e) => e['id'] == firstId).length, 1);
    expect(entries.length, 1);
  });

  test('missing idempotency_key records each analyze separately', () async {
    FormData form() => FormData.fromMap(<String, Object?>{
      'image': MultipartFile.fromBytes(<int>[1, 2, 3, 4], filename: 'meal.jpg'),
      'meal_type': 'lunch',
    });
    final a = await dio.post<Map<String, Object?>>(
      '/diet/analyze',
      data: form(),
    );
    final b = await dio.post<Map<String, Object?>>(
      '/diet/analyze',
      data: form(),
    );
    expect(a.data!['entry_id'], isNot(b.data!['entry_id']));

    final today = await dio.get<Map<String, Object?>>('/diet/days/today');
    final entries = (today.data!['entries']! as List<Object?>);
    expect(entries.length, 2);
  });

  test('PUT /diet/entries persists edited foods and nutrition', () async {
    await db
        .into(db.dietEntries)
        .insert(
          DietEntriesCompanion.insert(
            id: 'diet-edit',
            date: DateTime.now().toIso8601String().substring(0, 10),
            mealType: 'lunch',
            timeLabel: '12:00',
            foodsJson: jsonEncode(<Map<String, Object?>>[
              <String, Object?>{
                'name': '기존 음식',
                'calories': 100,
                'sodium_mg': 100,
                'sugar_g': 1,
                'carbs_g': 10,
                'protein_g': 2,
                'fat_g': 1,
              },
            ]),
            totalCalories: 100,
            sodiumMg: const Value(100),
            sugarG: const Value(1),
          ),
        );
    final editedFoods = <Map<String, Object?>>[
      <String, Object?>{
        'name': '현미밥',
        'calories': 220,
        'sodium_mg': 5,
        'sugar_g': 0,
        'carbs_g': 46.0,
        'protein_g': 5.0,
        'fat_g': 1.8,
      },
      <String, Object?>{
        'name': '닭가슴살',
        'calories': 165,
        'sodium_mg': 74,
        'sugar_g': 0,
        'carbs_g': 0.0,
        'protein_g': 31.0,
        'fat_g': 3.6,
      },
    ];

    final updated = await dio.put<Map<String, Object?>>(
      '/diet/entries/diet-edit',
      data: <String, Object?>{
        'foods': editedFoods,
        'total_calories': 385,
        'sodium_mg': 79,
        'sugar_g': 0,
      },
    );

    expect(updated.data!['foods'], editedFoods);
    expect(updated.data!['total_calories'], 385);
    expect(updated.data!['sodium_mg'], 79);
    expect(updated.data!['sugar_g'], 0);
    expect(updated.data!['carbs_g'], 46.0);
    expect(updated.data!['protein_g'], 36.0);
    expect(updated.data!['fat_g'], closeTo(5.4, 0.001));

    final today = await dio.get<Map<String, Object?>>('/diet/days/today');
    final entries = (today.data!['entries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final persisted = entries.singleWhere(
      (Map<String, Object?> entry) => entry['id'] == 'diet-edit',
    );
    expect(persisted['foods'], editedFoods);
    expect(persisted['total_calories'], 385);
    expect(persisted['sodium_mg'], 79);
    expect(persisted['sugar_g'], 0);
    expect(persisted['carbs_g'], 46.0);
    expect(persisted['protein_g'], 36.0);
    expect(persisted['fat_g'], closeTo(5.4, 0.001));

    final mealOnly = await dio.put<Map<String, Object?>>(
      '/diet/entries/diet-edit',
      data: <String, Object?>{'meal_type': 'dinner'},
    );
    expect(mealOnly.data!['meal_type'], 'dinner');
    expect(mealOnly.data!['foods'], editedFoods);
    expect(mealOnly.data!['carbs_g'], 46.0);
    expect(mealOnly.data!['protein_g'], 36.0);
    expect(mealOnly.data!['fat_g'], closeTo(5.4, 0.001));
  });

  test('PUT /diet/entries rejects an invalid foods value', () async {
    await db
        .into(db.dietEntries)
        .insert(
          DietEntriesCompanion.insert(
            id: 'diet-invalid-foods',
            date: DateTime.now().toIso8601String().substring(0, 10),
            mealType: 'lunch',
            timeLabel: '12:00',
            foodsJson: jsonEncode(<Map<String, Object?>>[
              <String, Object?>{'name': '기존 음식', 'calories': 100},
            ]),
            totalCalories: 100,
          ),
        );

    final response = await dio.put<Map<String, Object?>>(
      '/diet/entries/diet-invalid-foods',
      data: <String, Object?>{'foods': 'not-a-list', 'total_calories': 999},
      options: Options(validateStatus: (_) => true),
    );

    expect(response.statusCode, 400);
    final row = await (db.select(
      db.dietEntries,
    )..where((table) => table.id.equals('diet-invalid-foods'))).getSingle();
    expect(
      row.foodsJson,
      jsonEncode(<Map<String, Object?>>[
        <String, Object?>{'name': '기존 음식', 'calories': 100},
      ]),
    );
    expect(row.totalCalories, 100);
  });
}
