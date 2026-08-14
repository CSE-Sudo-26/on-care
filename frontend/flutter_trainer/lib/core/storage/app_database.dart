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
  RealColumn get sugarG => real()();
  RealColumn get carbsG => real().withDefault(const Constant(0))();
  RealColumn get proteinG => real().withDefault(const Constant(0))();
  RealColumn get fatG => real().withDefault(const Constant(0))();
  TextColumn get lastRoutine => text()();
  TextColumn get weekCompletionJson => text()(); // [100, 67, ...] length 7
  // Last 7 days of daily sodium (mg), oldest→today (last == today).
  // Added in schema v2; the default keeps pre-v2 rows valid until the
  // next re-seed backfills it.
  TextColumn get sodiumWeekJson => text().withDefault(
    const Constant('[]'),
  )(); // [.., 2100] len 7, ends today
  // 나트륨과 **같은 창**의 칼로리·당류 추이(#746). 지표를 바꿔 가며 한 그래프로
  // 보므로 셋의 길이·기준일이 같아야 x 축이 어긋나지 않는다. 당류는 소수를
  // 유지한다 — 반올림하면 식단 탭 수치와 어긋난다.
  TextColumn get caloriesWeekJson => text().withDefault(const Constant('[]'))();
  TextColumn get sugarWeekJson => text().withDefault(const Constant('[]'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A single meal in a client's day (아침/점심/저녁/간식).
@DataClassName('ClientDietEntryRow')
class ClientDietEntries extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text()();
  TextColumn get meal => text()(); // 아침|점심|저녁|간식
  TextColumn get items => text()();
  IntColumn get calories => integer()();
  IntColumn get sodiumMg => integer()();
  RealColumn get carbsG => real().withDefault(const Constant(0))();
  RealColumn get proteinG => real().withDefault(const Constant(0))();
  RealColumn get fatG => real().withDefault(const Constant(0))();
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
  /// 예약된 고객의 id. 이름은 식별자가 아니다 — 고객 이름을 바꾸면 과거
  /// 세션이 통째로 끊기고, 조용히 "세션 0건" 리포트가 되어 그대로 회원에게
  /// 전송될 수 있었다(#386).
  ///
  /// nullable 인 이유: 상담 등 미등록 고객 슬롯과 공백 슬롯에는 붙일 id 가
  /// 없고, v3 이전에 저장된 기존 행도 값이 없다. 조회는 id 를 우선하고
  /// 없을 때만 이름으로 폴백한다.
  TextColumn get clientId => text().nullable()();
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
  int get schemaVersion => 6;

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
      // v3: 스케줄이 고객을 이름 대신 id 로 참조한다(#386). 기존 행은 null 로
      // 남고 조회가 이름으로 폴백하므로, 다음 재시딩 전까지도 끊기지 않는다.
      if (from < 3) {
        await m.addColumn(
          trainerScheduleEntries,
          trainerScheduleEntries.clientId,
        );
      }
      // v4: #527 client roster totals and per-meal macronutrients.
      // Defaults keep existing demo rows readable until the next re-seed.
      if (from < 4) {
        await m.addColumn(trainerClients, trainerClients.carbsG);
        await m.addColumn(trainerClients, trainerClients.proteinG);
        await m.addColumn(trainerClients, trainerClients.fatG);
        await m.addColumn(clientDietEntries, clientDietEntries.carbsG);
        await m.addColumn(clientDietEntries, clientDietEntries.proteinG);
        await m.addColumn(clientDietEntries, clientDietEntries.fatG);
      }
      if (from < 5) {
        // #565 sugar_g: INTEGER -> REAL. SQLite keeps non-integral values
        // stored in an INTEGER-affinity column as REAL, so rebuilding this
        // table would only add data-loss risk. Existing integers are read by
        // drift as doubles (for example 17 -> 17.0), while the v5 declaration
        // lets new values retain their fractional part.
      }
      // v6: 지표 선택형 추이 그래프가 쓸 주간 칼로리·당류(#746). 기본값이
      // 있어 기존 데모 행도 그대로 읽히고, 다음 재시딩이 실제 값을 채운다.
      if (from < 6) {
        await m.addColumn(trainerClients, trainerClients.caloriesWeekJson);
        await m.addColumn(trainerClients, trainerClients.sugarWeekJson);
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
}

/// Provides the trainer [AppDatabase], closing it on dispose.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}, name: 'trainerAppDatabase');
