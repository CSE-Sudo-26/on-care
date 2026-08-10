import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';

void main() {
  test('v3 to v4 adds macro columns and preserves existing rows', () async {
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

    expect(version.read<int>('user_version'), 4);
    expect(client.id, 'existing-client');
    expect(client.caloriesToday, 500);
    expect(client.carbsG, 0);
    expect(client.proteinG, 0);
    expect(client.fatG, 0);
    expect(meal.id, 'existing-meal');
    expect(meal.items, '기존 식단');
    expect(meal.carbsG, 0);
    expect(meal.proteinG, 0);
    expect(meal.fatG, 0);
  });
}
