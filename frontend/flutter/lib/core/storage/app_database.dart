import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Generic key-value table. Used for tiny app-level state (locale,
/// onboarding flags) and as a stash for JSON snapshots that don't yet
/// warrant their own table (MyHealthState, AiCoachState, …).
class AppKeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DataClassName('DietEntryRow')
class DietEntries extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get mealType => text()(); // breakfast|lunch|dinner|snack
  TextColumn get timeLabel => text()(); // "08:20"
  TextColumn get foodsJson => text()(); // [{ "name": "...", "calories": ... }]
  IntColumn get totalCalories => integer()();
  IntColumn get sodiumMg => integer().withDefault(const Constant(0))();
  // 당류만 실수. 서버 계약(diet_entries.sugar_g)이 float 이고 도메인 엔티티도
  // double 이라, 로컬 캐시만 정수면 데모 모드에서 8.5 가 8 로 잘린다.
  RealColumn get sugarG => real().withDefault(const Constant(0.0))();
  // 재시도 중복 저장 방지 멱등키(요청당 1회). 무키 요청은 null.
  TextColumn get idempotencyKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('ExerciseSessionRow')
class ExerciseSessions extends Table {
  TextColumn get id => text()();
  TextColumn get weekStart => text()(); // Monday YYYY-MM-DD
  TextColumn get dayLabel => text()(); // 월/화/수/...
  TextColumn get type => text()(); // cardio|strength|yoga|walking
  IntColumn get minutes => integer()();
  IntColumn get calories => integer()();
  TextColumn get intensity =>
      text().withDefault(const Constant('moderate'))(); // light|moderate|high
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('ScheduleEventRow')
class ScheduleEvents extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get time => text()(); // "10:00"
  TextColumn get title => text()();
  TextColumn get category =>
      text()(); // hospital|exercise|meal|medication|other
  TextColumn get emoji => text().withDefault(const Constant(''))();
  TextColumn get colorHex => text().withDefault(const Constant('#E0F2F7'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('NotificationRow')
class NotificationItems extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get category =>
      text()(); // reminder|health_check|achievement|system
  BoolColumn get read => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(
  tables: <Type>[
    AppKeyValues,
    DietEntries,
    ExerciseSessions,
    ScheduleEvents,
    NotificationItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'oncare',
          // On web, drift needs the sqlite3 WASM module and a worker
          // script. The release CI downloads both into `web/` so the
          // bundled `index.html` can fetch them at the same origin.
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  /// Use in tests:
  ///   `AppDatabase.forTesting(NativeDatabase.memory())`
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(dietEntries);
        await m.createTable(exerciseSessions);
        await m.createTable(scheduleEvents);
        await m.createTable(notificationItems);
      }
      if (from < 3) {
        // 운동 강도(intensity) 컬럼 추가 — 기존 행은 기본값 moderate.
        await m.addColumn(exerciseSessions, exerciseSessions.intensity);
      }
      if (from < 4) {
        // 식단 멱등키(idempotency_key) 컬럼 추가 — 기존 행은 null.
        await m.addColumn(dietEntries, dietEntries.idempotencyKey);
      }
      if (from < 5) {
        // 바이탈(체중/혈압/혈당) 기능 제거 — 기존 vitals 테이블 폐기.
        // v2~v4 에서만 vitals 가 생성됐고 v1 DB 에는 없으므로, 없는 테이블을
        // 지우다 실패하지 않도록 IF EXISTS 로 안전하게 드롭한다.
        await customStatement('DROP TABLE IF EXISTS vitals');
      }
      if (from < 6) {
        // 당류 sugar_g: INTEGER → REAL. 테이블을 다시 만들 필요는 없다.
        // SQLite 의 INTEGER 친화도는 "무손실일 때만" 정수로 바꾸므로 8.5 는
        // 그대로 REAL 로 저장되고, 읽을 때는 drift 가 선언 타입(double)으로
        // 매핑한다. 기존 정수 값도 8 → 8.0 으로 읽혀 손실이 없다.
        // 스키마 버전만 올려 이 결정을 기록해 둔다.
      }
    },
  );

  // ---- AppKeyValues ----
  Future<void> putValue(String key, String value) {
    return into(appKeyValues).insertOnConflictUpdate(
      AppKeyValuesCompanion.insert(key: key, value: value),
    );
  }

  Future<String?> readValue(String key) async {
    final row = await (select(
      appKeyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> deleteValue(String key) {
    return (delete(appKeyValues)..where((t) => t.key.equals(key))).go();
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}, name: 'appDatabase');
