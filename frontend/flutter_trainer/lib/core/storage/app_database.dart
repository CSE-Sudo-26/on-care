import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Generic key-value table. Holds tiny app-level state — currently the
/// seed flag (`trainer_seeded_v1`).
class AppKeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// A trainer's client (담당 고객). Mirrors the On-Care Figma
/// `TRAINER_CLIENTS` shape. Per-day nutrition totals are denormalised
/// here (as in the mock) for the quick-metric row on the client list.
@DataClassName('TrainerClientRow')
class TrainerClients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatar => text()(); // single-char avatar label ("김")
  TextColumn get goal => text()();
  TextColumn get lastMessage => text()();
  TextColumn get lastTime => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get caloriesToday => integer()();
  IntColumn get sodiumMg => integer()();
  IntColumn get sugarG => integer()();
  TextColumn get lastRoutine => text()();
  TextColumn get weekCompletionJson => text()(); // [100, 67, ...] length 7
  // Last 7 days of daily sodium (mg), oldest→today (last == today).
  // Added in schema v2; the default keeps pre-v2 rows valid until the
  // next re-seed backfills it.
  TextColumn get sodiumWeekJson => text().withDefault(
    const Constant('[]'),
  )(); // [.., 2100] len 7, ends today
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A single meal in a client's day (아침/점심/저녁).
@DataClassName('ClientDietEntryRow')
class ClientDietEntries extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text()();
  TextColumn get meal => text()(); // 아침|점심|저녁
  TextColumn get items => text()();
  IntColumn get calories => integer()();
  IntColumn get sodiumMg => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// An AI-suggested routine item for a client (AI 루틴 탭의 추천 루틴).
@DataClassName('ClientAiRoutineRow')
class ClientAiRoutines extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text()();
  TextColumn get name => text()();
  IntColumn get minutes => integer()();
  TextColumn get type => text()(); // 유산소|근력|스트레칭
  TextColumn get reason => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A past workout entry in a client's history (운동 기록 서브탭).
@DataClassName('ClientRoutineHistoryRow')
class ClientRoutineHistory extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text()();
  TextColumn get dateLabel => text()(); // "7/12 (오늘)"
  TextColumn get label => text()(); // "PT 세션 · 트레이너 지도"
  IntColumn get completionRate => integer()(); // 0..100
  TextColumn get exercisesJson => text()(); // ["레그프레스 3세트", ...]
  TextColumn get clientFeedback => text().withDefault(const Constant(''))();
  TextColumn get trainerNote => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A chat message between the trainer and a client. Trainer-sent
/// messages added at runtime get a non-`seed-` id so they survive
/// re-seeding.
@DataClassName('ClientChatMessageRow')
class ClientChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text()();
  TextColumn get sender => text()(); // trainer|client
  TextColumn get body => text()(); // message text ('text' collides with text())
  TextColumn get timeLabel => text()(); // "18:10"
  DateTimeColumn get createdAt => dateTime()(); // ordering key

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A slot on the trainer's daily schedule (스케줄 탭 타임라인).
@DataClassName('TrainerScheduleRow')
class TrainerScheduleEntries extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD (slides to today)
  TextColumn get time => text()(); // "10:00"
  TextColumn get clientName => text().withDefault(const Constant(''))();
  TextColumn get type => text().withDefault(const Constant(''))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  TextColumn get status => text()(); // 완료|예정|공백
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get programJson =>
      text().withDefault(const Constant('[]'))(); // [{name,sets,reps,weight}]
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Trainer-app local database (drift-backed). Holds mock client /
/// schedule data until the FastAPI backend lands. Designed fresh for
/// the trainer app — the user app's database is not reused.
@DriftDatabase(
  tables: <Type>[
    AppKeyValues,
    TrainerClients,
    ClientDietEntries,
    ClientAiRoutines,
    ClientRoutineHistory,
    ClientChatMessages,
    TrainerScheduleEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database (native on mobile, WASM on web).
  AppDatabase()
    : super(
        driftDatabase(
          name: 'oncare_trainer',
          // On web, drift needs the sqlite3 WASM module + worker script
          // served at the same origin. Provided by the web build/deploy
          // step (as in the user app).
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  /// Test constructor:
  ///   `AppDatabase.forTesting(NativeDatabase.memory())`
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // v2: 7-day sodium trend on the client row (defaults keep old rows
      // valid; the next re-seed backfills real values).
      if (from < 2) {
        await m.addColumn(trainerClients, trainerClients.sodiumWeekJson);
      }
    },
  );

  // ---- AppKeyValues helpers ----

  /// Upserts a key-value pair.
  Future<void> putValue(String key, String value) {
    return into(appKeyValues).insertOnConflictUpdate(
      AppKeyValuesCompanion.insert(key: key, value: value),
    );
  }

  /// Reads a value, or `null` if absent.
  Future<String?> readValue(String key) async {
    final row = await (select(
      appKeyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Deletes a key.
  Future<void> deleteValue(String key) {
    return (delete(appKeyValues)..where((t) => t.key.equals(key))).go();
  }
}

/// Provides the trainer [AppDatabase], closing it on dispose.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}, name: 'trainerAppDatabase');
