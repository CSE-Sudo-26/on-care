import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';

void main() {
  test(
    'v3 to v6 adds macro·주간 계열 columns and preserves existing rows',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE trainer_clients (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            avatar TEXT NOT NULL,
            goal TEXT NOT NULL,
            last_message TEXT NOT NULL,
            last_time TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
            calories_today INTEGER NOT NULL,
            sodium_mg INTEGER NOT NULL,
            sugar_g INTEGER NOT NULL,
            last_routine TEXT NOT NULL,
            week_completion_json TEXT NOT NULL,
            sodium_week_json TEXT NOT NULL DEFAULT '[]',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
          database.execute('''
          CREATE TABLE client_diet_entries (
            id TEXT NOT NULL PRIMARY KEY,
            client_id TEXT NOT NULL,
            meal TEXT NOT NULL,
            items TEXT NOT NULL,
            calories INTEGER NOT NULL,
            sodium_mg INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
          database.execute('''
          INSERT INTO trainer_clients (
            id, name, avatar, goal, last_message, last_time, active,
            calories_today, sodium_mg, sugar_g, last_routine,
            week_completion_json, sodium_week_json, sort_order
          ) VALUES (
            'existing-client', '기존 회원', '기', '건강 관리', '', '-', 1,
            500, 700, 12, '어제', '[100,0,0,0,0,0,0]', '[700]', 1
          )
        ''');
          database.execute('''
          INSERT INTO client_diet_entries (
            id, client_id, meal, items, calories, sodium_mg, sort_order
          ) VALUES (
            'existing-meal', 'existing-client', '아침', '기존 식단', 500, 700, 0
          )
        ''');
          database.execute('PRAGMA user_version = 3');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);

      final client = await db.select(db.trainerClients).getSingle();
      final meal = await db.select(db.clientDietEntries).getSingle();
      final version = await db.customSelect('PRAGMA user_version').getSingle();

      expect(version.read<int>('user_version'), 7);
      expect(client.id, 'existing-client');
      expect(client.caloriesToday, 500);
      expect(client.sugarG, 12.0);
      expect(client.carbsG, 0);
      // 새 주간 계열은 기본값으로 들어와 다음 재시딩이 실제 값을 채운다(#746).
      expect(client.caloriesWeekJson, '[]');
      expect(client.sugarWeekJson, '[]');
      expect(client.proteinG, 0);
      expect(client.fatG, 0);
      expect(meal.id, 'existing-meal');
      expect(meal.items, '기존 식단');
      expect(meal.carbsG, 0);
      expect(meal.proteinG, 0);
      expect(meal.fatG, 0);
    },
  );

  test('v4 to v7 preserves integer sugar and all client rows', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''
          CREATE TABLE trainer_clients (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            avatar TEXT NOT NULL,
            goal TEXT NOT NULL,
            last_message TEXT NOT NULL,
            last_time TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
            calories_today INTEGER NOT NULL,
            sodium_mg INTEGER NOT NULL,
            sugar_g INTEGER NOT NULL,
            carbs_g REAL NOT NULL DEFAULT 0,
            protein_g REAL NOT NULL DEFAULT 0,
            fat_g REAL NOT NULL DEFAULT 0,
            last_routine TEXT NOT NULL,
            week_completion_json TEXT NOT NULL,
            sodium_week_json TEXT NOT NULL DEFAULT '[]',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        database.execute('''
          INSERT INTO trainer_clients (
            id, name, avatar, goal, last_message, last_time, active,
            calories_today, sodium_mg, sugar_g, carbs_g, protein_g, fat_g,
            last_routine, week_completion_json, sodium_week_json, sort_order
          ) VALUES
            ('client-a', '기존 회원 A', 'A', '혈압 관리', '보존 메시지', '방금', 1,
             500, 700, 12, 40.5, 20, 10, '어제', '[100]', '[700]', 1),
            ('client-b', '기존 회원 B', 'B', '체중 감량', '다른 메시지', '1시간 전', 0,
             900, 1200, 61, 80, 35.5, 22, '3일 전', '[50]', '[1200]', 2)
        ''');
        database.execute('PRAGMA user_version = 4');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    final clients = await db.select(db.trainerClients).get()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final version = await db.customSelect('PRAGMA user_version').getSingle();

    expect(version.read<int>('user_version'), 7);
    expect(clients, hasLength(2));
    expect(clients[0].name, '기존 회원 A');
    expect(clients[0].sugarG, 12.0);
    expect(clients[0].carbsG, 40.5);
    expect(clients[1].name, '기존 회원 B');
    expect(clients[1].active, isFalse);
    expect(clients[1].sugarG, 61.0);
    expect(clients[1].proteinG, 35.5);
    expect(clients[0].caloriesWeekJson, '[]');
    expect(clients[1].sugarWeekJson, '[]');
  });

  test(
    'v5 to v6 adds the weekly calorie·sugar series to existing rows',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE trainer_clients (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            avatar TEXT NOT NULL,
            goal TEXT NOT NULL,
            last_message TEXT NOT NULL,
            last_time TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
            calories_today INTEGER NOT NULL,
            sodium_mg INTEGER NOT NULL,
            sugar_g REAL NOT NULL,
            carbs_g REAL NOT NULL DEFAULT 0,
            protein_g REAL NOT NULL DEFAULT 0,
            fat_g REAL NOT NULL DEFAULT 0,
            last_routine TEXT NOT NULL,
            week_completion_json TEXT NOT NULL,
            sodium_week_json TEXT NOT NULL DEFAULT '[]',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
          database.execute('''
          INSERT INTO trainer_clients (
            id, name, avatar, goal, last_message, last_time, active,
            calories_today, sodium_mg, sugar_g, carbs_g, protein_g, fat_g,
            last_routine, week_completion_json, sodium_week_json, sort_order
          ) VALUES (
            'client-a', '기존 회원 A', 'A', '혈압 관리', '보존 메시지', '방금', 1,
            500, 700, 17.8, 40.5, 20, 10, '어제', '[100]', '[700,800]', 1
          )
        ''');
          database.execute('PRAGMA user_version = 5');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);

      final client = await db.select(db.trainerClients).getSingle();
      final version = await db.customSelect('PRAGMA user_version').getSingle();

      expect(version.read<int>('user_version'), 7);
      // 기존 값은 그대로 두고, 새 계열만 기본값으로 붙는다.
      expect(client.sugarG, 17.8);
      expect(client.sodiumWeekJson, '[700,800]');
      expect(client.caloriesWeekJson, '[]');
      expect(client.sugarWeekJson, '[]');
    },
  );
}
