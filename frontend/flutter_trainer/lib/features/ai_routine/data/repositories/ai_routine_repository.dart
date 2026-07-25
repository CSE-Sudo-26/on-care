import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/ai_routine_item.dart';

/// Reads a client's AI-suggested routine from the local drift DB.
class AiRoutineRepository {
  /// Creates the repository over [_db].
  const AiRoutineRepository(this._db);

  final AppDatabase _db;

  /// The AI suggestions for [clientId], in seeded order.
  Stream<List<AiRoutineItem>> watchRoutine(String clientId) {
    final query = _db.select(_db.clientAiRoutines)
      ..where((t) => t.clientId.equals(clientId))
      ..orderBy(<OrderingTerm Function($ClientAiRoutinesTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => AiRoutineItem(
              id: row.id,
              name: row.name,
              minutes: row.minutes,
              type: row.type,
              reason: row.reason,
            ),
          )
          .toList(),
    );
  }
}

/// Provides the [AiRoutineRepository].
final aiRoutineRepositoryProvider = Provider<AiRoutineRepository>((ref) {
  return AiRoutineRepository(ref.watch(appDatabaseProvider));
});

/// Streams a client's AI routine suggestions.
final aiRoutineProvider = StreamProvider.family<List<AiRoutineItem>, String>((
  ref,
  clientId,
) {
  return ref.watch(aiRoutineRepositoryProvider).watchRoutine(clientId);
});
