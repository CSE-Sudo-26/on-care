import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';

/// Reads the trainer's daily timeline from the local drift DB.
class ScheduleRepository {
  /// Creates the repository over [_db].
  const ScheduleRepository(this._db);

  final AppDatabase _db;

  /// Today's slots in timeline order (including 공백 gaps).
  ///
  /// NOTE: `ymd(DateTime.now())`는 스트림 구독 시점에 고정된다 — 앱을
  /// 자정 넘겨 켜두면 '오늘'이 갱신되지 않음(예약 카운트와 동일 패턴,
  /// 로컬 mock 데모 범위에선 허용). 실 백엔드 전환 시 서버가 판단한다.
  Stream<List<ScheduleSession>> watchToday() => watchDate(ymd(DateTime.now()));

  /// The timeline for one calendar [date] (`YYYY-MM-DD`).
  Stream<List<ScheduleSession>> watchDate(String date) {
    final query = _db.select(_db.trainerScheduleEntries)
      ..where((t) => t.date.equals(date))
      // Time first (zero-padded HH:MM sorts lexicographically) so
      // trainer-added sessions land at the right timeline position;
      // sortOrder only breaks ties between seed rows.
      ..orderBy(<OrderingTerm Function($TrainerScheduleEntriesTable)>[
        (t) => OrderingTerm(expression: t.time),
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// Dates (`YYYY-MM-DD`) that have at least one booked (non-공백)
  /// session — drives the week strip's dot markers.
  Stream<Set<String>> watchBookedDates() {
    final t = _db.trainerScheduleEntries;
    final query = _db.selectOnly(t, distinct: true)
      ..addColumns(<Expression<Object>>[t.date])
      ..where(t.status.equals('공백').not());
    return query
        .map((row) => row.read(t.date)!)
        .watch()
        .map((rows) => rows.toSet());
  }

  /// Every slot between [fromDate] and [toDate] inclusive (`YYYY-MM-DD`),
  /// ordered by day then time. Backs the week calendar — one query for
  /// the whole week rather than seven day subscriptions.
  Stream<List<ScheduleSession>> watchRange(String fromDate, String toDate) {
    final query = _db.select(_db.trainerScheduleEntries)
      // `YYYY-MM-DD` is lexicographically ordered, so a string BETWEEN
      // is a correct date-range filter here.
      ..where(
        (t) =>
            t.date.isBiggerOrEqualValue(fromDate) &
            t.date.isSmallerOrEqualValue(toDate),
      )
      ..orderBy(<OrderingTerm Function($TrainerScheduleEntriesTable)>[
        (t) => OrderingTerm(expression: t.date),
        (t) => OrderingTerm(expression: t.time),
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// A client's booked sessions, newest first. Drives the 고객 상세 루틴
  /// tab (what programs this person has been given).
  ///
  /// Schedules reference a client by NAME — see `addClient`'s uniqueness
  /// guard, which exists precisely so this lookup can't collide. Matched
  /// on `lower(trim(name))`, the SAME normalisation that guard uses: an
  /// exact compare would silently return nothing for a name stored with
  /// stray whitespace or different case, and the weekly report would
  /// then show 0 sessions for a client who clearly has some.
  Stream<List<ScheduleSession>> watchClientSessions(String clientName) {
    final query = _db.select(_db.trainerScheduleEntries)
      ..where(
        (t) =>
            t.clientName.lower().trim().equals(
              clientName.trim().toLowerCase(),
            ) &
            t.status.equals('공백').not(),
      )
      ..orderBy(<OrderingTerm Function($TrainerScheduleEntriesTable)>[
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.time, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// Books a new session on [date]'s timeline (status 예정). The
  /// non-`seed-` id survives the daily re-seed.
  Future<void> addSession({
    required String date,
    required String clientName,
    required String time,
    required String type,
    required int durationMinutes,
    String note = '',
  }) async {
    await _db
        .into(_db.trainerScheduleEntries)
        .insert(
          TrainerScheduleEntriesCompanion.insert(
            id: 'sched-${DateTime.now().microsecondsSinceEpoch}',
            date: date,
            time: time,
            clientName: Value(clientName),
            type: Value(type),
            durationMinutes: Value(durationMinutes),
            status: '예정',
            programJson: const Value('[]'),
            note: Value(note),
          ),
        );
  }

  /// Edits a booked session's time/client/type/duration.
  Future<void> updateSession(
    String id, {
    required String clientName,
    required String time,
    required String type,
    required int durationMinutes,
    required String note,
  }) async {
    await (_db.update(
      _db.trainerScheduleEntries,
    )..where((t) => t.id.equals(id))).write(
      TrainerScheduleEntriesCompanion(
        clientName: Value(clientName),
        time: Value(time),
        type: Value(type),
        durationMinutes: Value(durationMinutes),
        note: Value(note),
      ),
    );
  }

  /// Replaces the exercise program and trainer memo without changing the
  /// booking itself (client, type, time, or duration).
  Future<void> updateProgram(
    String id, {
    required List<ProgramItem> program,
    required String note,
  }) async {
    await (_db.update(
      _db.trainerScheduleEntries,
    )..where((t) => t.id.equals(id))).write(
      TrainerScheduleEntriesCompanion(
        programJson: Value(
          jsonEncode(<Map<String, Object>>[
            for (final item in program)
              <String, Object>{
                'name': item.name,
                'sets': item.sets,
                'reps': item.reps,
                'weight': item.weight,
              },
          ]),
        ),
        note: Value(note),
      ),
    );
  }

  /// Removes a session from the timeline.
  Future<void> deleteSession(String id) async {
    await (_db.delete(
      _db.trainerScheduleEntries,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Marks an 예정 session 완료 (with the trainer's [note]) and, when the
  /// client exists, logs it to their 운동기록 history — closing the
  /// 예약 → 수업 → 기록 loop.
  ///
  /// Idempotent: the read, the status-guarded update and the history
  /// insert all run inside ONE transaction, and history is written only
  /// when this call is the one that flipped 예정 → 완료. Two concurrent
  /// completions would otherwise both observe 예정 and insert duplicate
  /// history rows (review PR 237).
  ///
  /// A session dated in the FUTURE can't be completed — it hasn't
  /// happened yet. The UI hides the 완료 action for future days, and this
  /// guard rejects it even if reached another way (review PR 245).
  Future<void> completeSession(String id, {String note = ''}) async {
    final table = _db.trainerScheduleEntries;
    final today = ymd(DateTime.now());

    await _db.transaction(() async {
      final session = await (_db.select(
        table,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (session == null || session.status != '예정') return;
      // `YYYY-MM-DD` sorts lexicographically, so a plain compare works.
      if (session.date.compareTo(today) > 0) return;

      // Conditional update: `changed` is 0 when a concurrent call already
      // completed this session, in which case we must not log again.
      final changed =
          await (_db.update(
            table,
          )..where((t) => t.id.equals(id) & t.status.equals('예정'))).write(
            TrainerScheduleEntriesCompanion(
              status: const Value('완료'),
              // An empty memo must not wipe an existing note.
              note: note.isEmpty ? const Value.absent() : Value(note),
            ),
          );
      if (changed != 1) return;

      final client =
          await (_db.select(_db.trainerClients)
                ..where((t) => t.name.equals(session.clientName))
                ..limit(1))
              .getSingleOrNull();

      // 상담 등 미등록 고객은 기록 없이 완료만 처리한다.
      if (client == null) return;
      final program = (jsonDecode(session.programJson) as List<Object?>)
          .map((e) => e! as Map<String, Object?>)
          .toList();
      final now = DateTime.now();
      // Label with the SESSION's calendar day — completing a session
      // browsed on another date must not claim '오늘'.
      final day = DateTime.tryParse(session.date) ?? now;
      final isToday = session.date == ymd(now);
      await _db
          .into(_db.clientRoutineHistory)
          .insert(
            ClientRoutineHistoryCompanion.insert(
              // Include the session id: on web (JS Date) microseconds have
              // only ms resolution, so two same-ms completions would
              // otherwise collide on this PK (review PR 237).
              id: 'hist-$id-${now.microsecondsSinceEpoch}',
              clientId: client.id,
              dateLabel: '${day.month}/${day.day}${isToday ? ' (오늘)' : ''}',
              label: 'PT 세션 · 트레이너 지도',
              completionRate: 100,
              exercisesJson: jsonEncode(<String>[
                for (final m in program)
                  (m['sets'] as int? ?? 1) > 1
                      ? '${m['name']} ${m['sets']}세트'
                      : '${m['name']} ${m['reps']}',
              ]),
              trainerNote: Value(note),
              // Seed rows use ascending sortOrder from 0; a negative,
              // decreasing key keeps runtime completions newest-first.
              sortOrder: Value(-now.millisecondsSinceEpoch),
            ),
          );
    });
  }

  ScheduleSession _toEntity(TrainerScheduleRow row) {
    final program = (jsonDecode(row.programJson) as List<Object?>)
        .map((e) => e! as Map<String, Object?>)
        .map(
          (m) => ProgramItem(
            name: m['name']! as String,
            sets: m['sets']! as int,
            reps: m['reps']! as String,
            weight: m['weight']! as String,
          ),
        )
        .toList();
    return ScheduleSession(
      id: row.id,
      date: row.date,
      time: row.time,
      clientName: row.clientName,
      type: row.type,
      durationMinutes: row.durationMinutes,
      status: row.status,
      note: row.note,
      program: program,
    );
  }
}

/// Provides the [ScheduleRepository].
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(appDatabaseProvider));
});

/// Streams today's timeline for the 스케줄 tab.
final todayScheduleProvider = StreamProvider<List<ScheduleSession>>((ref) {
  return ref.watch(scheduleRepositoryProvider).watchToday();
});

/// Streams the timeline for one calendar date (`YYYY-MM-DD`).
final scheduleForDateProvider =
    StreamProvider.family<List<ScheduleSession>, String>((ref, date) {
      return ref.watch(scheduleRepositoryProvider).watchDate(date);
    });

/// Streams the set of dates that have booked sessions (strip dots).
final bookedDatesProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(scheduleRepositoryProvider).watchBookedDates();
});

/// An inclusive `YYYY-MM-DD` date range, used to key the week query.
typedef ScheduleRange = ({String from, String to});

/// Streams every slot in a date range (week calendar).
final scheduleRangeProvider =
    StreamProvider.family<List<ScheduleSession>, ScheduleRange>((ref, range) {
      return ref
          .watch(scheduleRepositoryProvider)
          .watchRange(range.from, range.to);
    });

/// Streams one client's booked sessions, newest first.
final clientSessionsProvider =
    StreamProvider.family<List<ScheduleSession>, String>((ref, clientName) {
      return ref
          .watch(scheduleRepositoryProvider)
          .watchClientSessions(clientName);
    });
