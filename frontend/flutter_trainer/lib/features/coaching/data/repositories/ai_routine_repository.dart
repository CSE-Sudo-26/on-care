import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';

/// Reads a client's AI-suggested routine from the local drift DB.
class AiRoutineRepository {
  /// Creates the repository over [_db].
  const AiRoutineRepository(this._db);

  final AppDatabase _db;

  /// The AI suggestions for [clientId], in seeded order.
  ///
  /// Real API clients use backend ids (`user-demo`) while the bundled
  /// suggestions use demo ids (`seed-client-1`). [clientName] lets a live
  /// roster resolve the corresponding local suggestion set.
  Stream<List<AiRoutineItem>> watchRoutine(
    String clientId, {
    String? clientName,
  }) {
    final routines = _db.clientAiRoutines;
    final clients = _db.trainerClients;
    final query = _db.select(routines).join(<Join>[
      innerJoin(
        clients,
        clients.id.equalsExp(routines.clientId),
        useColumns: false,
      ),
    ]);
    query.where(
      routines.clientId.equals(clientId) |
          (clientName == null
              ? const Constant<bool>(false)
              : clients.name.equals(clientName)),
    );
    return query.watch().map((rows) {
      final localRows = rows.map((row) => row.readTable(routines)).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return localRows
          .map(
            (row) => AiRoutineItem(
              id: row.id,
              name: row.name,
              minutes: row.minutes,
              type: row.type,
              reason: row.reason,
            ),
          )
          .toList();
    });
  }

  /// Registers the composed routine as [clientName]'s PT program on
  /// [date]'s schedule (스케줄 탭 watches the same table, so it updates
  /// live). Attaches to the client's earliest 예정 session on that date
  /// when one exists; otherwise books a new one-hour 예정 slot.
  /// Returns `true` when attached to an existing session.
  ///
  /// [program] entries follow the schedule programJson shape
  /// (`{name, sets, reps, weight}`).
  Future<bool> registerToSchedule({
    required String date,
    required String clientName,
    required List<Map<String, Object?>> program,
  }) async {
    final table = _db.trainerScheduleEntries;
    final existing =
        await (_db.select(table)
              ..where(
                (t) =>
                    t.date.equals(date) &
                    t.clientName.equals(clientName) &
                    t.status.equals('예정'),
              )
              ..orderBy(<OrderingTerm Function($TrainerScheduleEntriesTable)>[
                (t) => OrderingTerm(expression: t.time),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(table)..where((t) => t.id.equals(existing.id))).write(
        TrainerScheduleEntriesCompanion(
          programJson: Value(jsonEncode(program)),
        ),
      );
      return true;
    }

    final now = DateTime.now();
    // For today, the next full hour capped at the 23:00 slot: an evening
    // registration stays in the future (22:xx → 23:00) where the previous
    // cap of 22 produced a past 22:00. It does NOT cover 23:00–23:59 —
    // there is no later slot today, so that books an already-past 23:00;
    // register after 23:00 against the next day using the date picker.
    // A complete fix needs a server clock (review PR 220).
    // Other dates start at 10:00.
    final hour = date == ymd(now) ? (now.hour + 1).clamp(6, 23) : 10;
    await _db
        .into(table)
        .insert(
          TrainerScheduleEntriesCompanion.insert(
            id: 'sched-${now.microsecondsSinceEpoch}',
            date: date,
            time: '${hour.toString().padLeft(2, '0')}:00',
            clientName: Value(clientName),
            type: const Value('1:1 PT'),
            durationMinutes: const Value(60),
            status: '예정',
            programJson: Value(jsonEncode(program)),
          ),
        );
    return false;
  }
}

/// Provides the [AiRoutineRepository].
final aiRoutineRepositoryProvider = Provider<AiRoutineRepository>((ref) {
  return AiRoutineRepository(ref.watch(appDatabaseProvider));
});

/// A stable key for local suggestions when the live and demo ids differ.
typedef AiRoutineClientKey = ({String id, String name});

/// Streams a client's AI routine suggestions.
final aiRoutineProvider =
    StreamProvider.family<List<AiRoutineItem>, AiRoutineClientKey>((ref, key) {
      return ref
          .watch(aiRoutineRepositoryProvider)
          .watchRoutine(key.id, clientName: key.name);
    });
