import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';

void main() {
  test(
    'v3 to v12 adds macro·주간 계열·취소 기록 columns and preserves rows',
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
          // 이 테이블은 v1 부터 있었다. 스냅샷이 빼먹으면 그 위에서 도는
          // 마이그레이션이 실제 DB 와 다른 것을 보게 된다(#822).
          database.execute('''
          CREATE TABLE trainer_schedule_entries (
            id TEXT NOT NULL PRIMARY KEY,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            client_id TEXT,
            client_name TEXT NOT NULL DEFAULT '',
            type TEXT NOT NULL DEFAULT '',
            duration_minutes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            program_json TEXT NOT NULL DEFAULT '[]',
            sort_order INTEGER NOT NULL DEFAULT 0
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

      expect(version.read<int>('user_version'), 12);
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
      // v11 은 리포트 피드백 초안 표를 새로 만든다(#821). 예전 DB 에는 없던
      // 표라, 만들어지지 않으면 초안 저장이 첫 조회에서 죽는다.
      expect(await db.select(db.reportFeedbackDrafts).get(), isEmpty);
      // v12 는 일정에 취소·노쇼 기록 칸을 붙인다(#906). 붙지 않으면 취소를
      // 누르는 순간 없는 컬럼에 쓰다가 죽는다. 예전 행은 값이 없는 것이 정상이고,
      // 그 자체가 "취소가 아님" 이라는 뜻이다.
      final schedule = await db.select(db.trainerScheduleEntries).get();
      expect(schedule, isEmpty);
      await db
          .into(db.trainerScheduleEntries)
          .insert(
            TrainerScheduleEntriesCompanion.insert(
              id: 'migrated-session',
              date: '2026-08-19',
              time: '10:00',
              status: '취소',
              cancelledAt: Value(DateTime(2026, 8, 19, 9)),
              cancellationSource: const Value('member'),
              cancellationReason: const Value('고객 사정'),
            ),
          );
      final stored = await db.select(db.trainerScheduleEntries).getSingle();
      expect(stored.cancellationSource, 'member');
      expect(stored.cancellationReason, '고객 사정');
      expect(stored.cancelledAt, isNotNull);
      expect(stored.noShowAt, isNull);
    },
  );

  test('v4 to v12 preserves integer sugar and all client rows', () async {
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
        // 이 테이블은 v1 부터 있었다. 스냅샷이 빼먹으면 그 위에서 도는
        // 마이그레이션이 실제 DB 와 다른 것을 보게 된다(#822).
        database.execute('''
          CREATE TABLE trainer_schedule_entries (
            id TEXT NOT NULL PRIMARY KEY,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            client_id TEXT,
            client_name TEXT NOT NULL DEFAULT '',
            type TEXT NOT NULL DEFAULT '',
            duration_minutes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            program_json TEXT NOT NULL DEFAULT '[]',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // v1 부터 있던 테이블이다. 스냅샷이 빼먹으면 그 위에서 도는
        // 마이그레이션이 실제 DB 와 다른 것을 보게 된다(#819).
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
        database.execute('PRAGMA user_version = 4');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    final clients = await db.select(db.trainerClients).get()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final version = await db.customSelect('PRAGMA user_version').getSingle();

    expect(version.read<int>('user_version'), 12);
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
    'v5 to v11 adds the weekly calorie·sugar series to existing rows',
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
          // 이 테이블은 v1 부터 있었다. 스냅샷이 빼먹으면 그 위에서 도는
          // 마이그레이션이 실제 DB 와 다른 것을 보게 된다(#822).
          database.execute('''
          CREATE TABLE trainer_schedule_entries (
            id TEXT NOT NULL PRIMARY KEY,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            client_id TEXT,
            client_name TEXT NOT NULL DEFAULT '',
            type TEXT NOT NULL DEFAULT '',
            duration_minutes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            program_json TEXT NOT NULL DEFAULT '[]',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
          // v1 부터 있던 테이블이다. 스냅샷이 빼먹으면 그 위에서 도는
          // 마이그레이션이 실제 DB 와 다른 것을 보게 된다(#819).
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
          database.execute('PRAGMA user_version = 5');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);

      final client = await db.select(db.trainerClients).getSingle();
      final version = await db.customSelect('PRAGMA user_version').getSingle();

      expect(version.read<int>('user_version'), 12);
      // 기존 값은 그대로 두고, 새 계열만 기본값으로 붙는다.
      expect(client.sugarG, 17.8);
      expect(client.sodiumWeekJson, '[700,800]');
      expect(client.caloriesWeekJson, '[]');
      expect(client.sugarWeekJson, '[]');
    },
  );
}
