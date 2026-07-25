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
  Stream<List<ScheduleSession>> watchToday() {
    final query = _db.select(_db.trainerScheduleEntries)
      ..where((t) => t.date.equals(ymd(DateTime.now())))
      ..orderBy(<OrderingTerm Function($TrainerScheduleEntriesTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
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
