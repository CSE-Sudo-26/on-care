import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/clients/data/dtos/client_dtos.dart'
    show prioritizeClients;
import 'package:oncare_trainer/features/clients/data/repositories/dio_client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Reads a trainer's clients + their diet/history for the 고객 관리 tab.
///
/// Two implementations sit behind this contract (selected by
/// [clientRepositoryProvider] via [AppConfig.useMockApi]):
///  * [DriftClientRepository] — local drift, demo / `USE_MOCK_API=true`;
///  * [DioClientRepository] — the real FastAPI backend.
///
/// Reads are exposed as streams so the drift source can stay reactive; the
/// Dio source emits a single fetched value (loading/error surface through
/// the consuming `AsyncValue`).
abstract interface class ClientRepository {
  /// Whether this source supports adding clients and changing roster status.
  ///
  /// The real roster is managed by trainer-member links on the backend and
  /// currently has no mutation endpoints, so its UI must stay read-only.
  bool get supportsRosterMutations;

  Stream<List<TrainerClient>> watchClients();

  /// Most recent chat activity per client id — the tiebreak used by
  /// [prioritizeClients]. Sources without a chat signal emit `{}`.
  Stream<Map<String, DateTime>> watchLastChatAt();

  Stream<List<ClientDietEntry>> watchDiet(String clientId);
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId);

  /// Demo-only roster mutations — the backend roster comes from
  /// trainer↔member links, so these are unsupported against the real API.
  Future<bool> clientNameExists(String name);
  Future<bool> addClient({required String name, required String goal});
  Future<void> setClientActive(String id, bool active);
}

/// Reads client + schedule data from the local drift DB for the
/// 고객 관리 tab. Returns reactive streams so the UI updates if the
/// underlying rows change (e.g. a routine sent from another tab).
class DriftClientRepository implements ClientRepository {
  /// Creates the repository over [_db].
  const DriftClientRepository(this._db);

  final AppDatabase _db;

  @override
  bool get supportsRosterMutations => true;

  /// All clients, ordered as seeded (sortOrder).
  @override
  Stream<List<TrainerClient>> watchClients() {
    final query = _db.select(_db.trainerClients)
      ..orderBy(<OrderingTerm Function($TrainerClientsTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// Most recent message time per client.
  ///
  /// A plain grouped aggregate over the chat table — deliberately NOT a
  /// join against `trainerClients`. The joined form (`select(t).join(...)
  /// ..groupBy(...)`) never completes against the sqlite3 WASM build the
  /// web app runs on, which stalled the roster and the dashboard on a
  /// spinner with no error to show.
  @override
  Stream<Map<String, DateTime>> watchLastChatAt() {
    final chat = _db.clientChatMessages;
    final latest = chat.createdAt.max();
    final query = _db.selectOnly(chat)
      ..addColumns(<Expression<Object>>[chat.clientId, latest])
      ..groupBy(<Expression<Object>>[chat.clientId]);
    return query.watch().map((rows) {
      final out = <String, DateTime>{};
      for (final row in rows) {
        final id = row.read(chat.clientId);
        final at = row.read(latest);
        if (id != null && at != null) out[id] = at;
      }
      return out;
    });
  }

  /// Whether a client with this display name already exists
  /// (whitespace- and case-insensitive). Counts in SQL rather than
  /// loading every row into memory (review PR 243).
  @override
  Future<bool> clientNameExists(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return false;
    return _nameTaken(key);
  }

  /// SQL `COUNT(*)` of clients whose normalised name matches [key]
  /// (already trimmed + lower-cased). Runs inside the caller's
  /// transaction when there is one, so `addClient` can check-then-insert
  /// atomically.
  Future<bool> _nameTaken(String key) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM trainer_clients '
          'WHERE lower(trim(name)) = ?1',
          variables: <Variable<Object>>[Variable<String>(key)],
          readsFrom: <ResultSetImplementation<Object?, Object?>>{
            _db.trainerClients,
          },
        )
        .getSingle();
    return row.read<int>('c') > 0;
  }

  /// Registers a new client (e.g. after a 상담) with a fresh, empty
  /// profile. The non-`seed-` id survives the daily re-seed.
  ///
  /// Returns `false` — writing nothing — when the name is blank or
  /// already taken. Schedule rows reference a client by NAME (the chat
  /// shortcut and completion logging both look up `clientName`), so a
  /// duplicate name would attribute one client's chat/운동기록 to
  /// another. Keeping names unique closes that path until schedules
  /// carry a clientId (review PR 243).
  ///
  /// The duplicate check and the insert run in ONE transaction, so two
  /// concurrent adds of the same name can't both pass the check and both
  /// insert — exactly one wins, the other returns `false` (review 243).
  @override
  Future<bool> addClient({required String name, required String goal}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;
    return _db.transaction(() async {
      if (await _nameTaken(trimmedName.toLowerCase())) return false;
      final now = DateTime.now();
      await _db
          .into(_db.trainerClients)
          .insert(
            TrainerClientsCompanion.insert(
              id: 'client-${now.microsecondsSinceEpoch}',
              name: trimmedName,
              // runes.first survives surrogate pairs without pulling the
              // characters package into this pure-Dart service.
              avatar: String.fromCharCode(trimmedName.runes.first),
              goal: goal.trim().isEmpty ? '목표 설정 전' : goal.trim(),
              lastMessage: '아직 대화가 없어요',
              lastTime: '-',
              active: const Value(true),
              caloriesToday: 0,
              sodiumMg: 0,
              sugarG: 0,
              carbsG: const Value(0),
              proteinG: const Value(0),
              fatG: const Value(0),
              lastRoutine: '-',
              weekCompletionJson: '[0,0,0,0,0,0,0]',
              sodiumWeekJson: const Value('[]'),
              // Large key appends new clients after the seeded roster.
              sortOrder: Value(now.millisecondsSinceEpoch),
            ),
          );
      return true;
    });
  }

  /// Flips a client between 활성 and 휴면.
  @override
  Future<void> setClientActive(String id, bool active) async {
    await (_db.update(_db.trainerClients)..where((t) => t.id.equals(id))).write(
      TrainerClientsCompanion(active: Value(active)),
    );
  }

  /// A client's meals for the 식단 sub-tab, in seeded order (아침 → 저녁).
  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) {
    final query = _db.select(_db.clientDietEntries)
      ..where((t) => t.clientId.equals(clientId))
      ..orderBy(<OrderingTerm Function($ClientDietEntriesTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ClientDietEntry(
              meal: row.meal,
              items: row.items,
              calories: row.calories,
              sodiumMg: row.sodiumMg,
              carbsG: row.carbsG,
              proteinG: row.proteinG,
              fatG: row.fatG,
            ),
          )
          .toList(),
    );
  }

  /// A client's workout history for the 운동기록 sub-tab, newest first
  /// (seeded order).
  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) {
    final query = _db.select(_db.clientRoutineHistory)
      ..where((t) => t.clientId.equals(clientId))
      ..orderBy(<OrderingTerm Function($ClientRoutineHistoryTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => RoutineHistoryEntry(
              dateLabel: row.dateLabel,
              label: row.label,
              completionRate: row.completionRate,
              exercises: (jsonDecode(row.exercisesJson) as List<Object?>)
                  .map((e) => e! as String)
                  .toList(),
              clientFeedback: row.clientFeedback,
              trainerNote: row.trainerNote,
            ),
          )
          .toList(),
    );
  }

  TrainerClient _toEntity(TrainerClientRow row) {
    final week = (jsonDecode(row.weekCompletionJson) as List<Object?>)
        .map((e) => e as int)
        .toList();
    final sodiumWeek = (jsonDecode(row.sodiumWeekJson) as List<Object?>)
        // On web, JSON numbers can decode as double — `as int` would
        // throw, so normalise through num (review PR 247).
        .map((e) => (e as num).toInt())
        .toList();
    return TrainerClient(
      id: row.id,
      name: row.name,
      avatar: row.avatar,
      goal: row.goal,
      lastMessage: row.lastMessage,
      lastTime: row.lastTime,
      active: row.active,
      calories: row.caloriesToday,
      sodiumMg: row.sodiumMg,
      sugarG: row.sugarG,
      carbsG: row.carbsG,
      proteinG: row.proteinG,
      fatG: row.fatG,
      lastRoutine: row.lastRoutine,
      weekCompletion: week,
      sodiumWeek: sodiumWeek,
    );
  }
}

/// Provides the [ClientRepository]: the real Dio-backed source against the
/// FastAPI backend, or the local drift source for demo / `USE_MOCK_API=true`.
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockApi) {
    return DriftClientRepository(ref.watch(appDatabaseProvider));
  }
  return DioClientRepository(ref.watch(dioProvider));
});

/// Streams the client list for the 고객 관리 tab.
final clientsProvider = StreamProvider<List<TrainerClient>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients();
});

/// Streams the coaching-priority ordering of the client list.
///
/// Sodium over-target first, ties broken by the most recent chat. ONE
/// rule for both modes — the ordering lives in the pure
/// [prioritizeClients], and each source just supplies what it has (drift
/// has chat times, the real roster endpoint doesn't yet).
///
/// Derived from [clientsProvider] rather than issuing its own read, so a
/// screen watching both (the list + detail split) doesn't trigger two
/// `GET /trainer/clients` calls.
///
/// A plain `Provider<AsyncValue<…>>`, not a `StreamProvider`: re-wrapping
/// the roster in a stream meant the loading branch had to return an empty
/// stream, and an empty stream *completes* — the provider then sat in
/// `AsyncLoading` forever with nothing left to emit. Mapping the
/// `AsyncValue` keeps loading/error/data flowing through untouched.
final prioritizedClientsProvider = Provider<AsyncValue<List<TrainerClient>>>((
  ref,
) {
  final lastChat =
      ref.watch(lastChatAtProvider).valueOrNull ?? const <String, DateTime>{};
  return ref
      .watch(clientsProvider)
      .whenData((clients) => prioritizeClients(clients, lastChatAt: lastChat));
});

/// Streams the last chat time per client (priority tiebreak).
final lastChatAtProvider = StreamProvider<Map<String, DateTime>>((ref) {
  return ref.watch(clientRepositoryProvider).watchLastChatAt();
});

/// Today's booked-session count for the sidebar badge and dashboard KPI.
///
/// Derived from [todayScheduleProvider] rather than the roster: the count is
/// a property of the schedule, and the dashboard already subscribes to that
/// stream, so composing here avoids a second request for the same data.
/// 공백 slots are placeholders, not bookings, so they don't count.
///
/// Stays an [AsyncValue] on purpose. When the schedule is loading or failed
/// there is no honest number to show, and `valueOrNull` is null — the UI
/// hides the badge instead of claiming "0명 예약", which would be wrong.
final todayReservationCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(todayScheduleProvider)
      .whenData((sessions) => sessions.where((s) => !s.isGap).length);
});

/// Streams a client's meals for the 식단 sub-tab.
final clientDietProvider = StreamProvider.family<List<ClientDietEntry>, String>(
  (ref, clientId) {
    return ref.watch(clientRepositoryProvider).watchDiet(clientId);
  },
);

/// Streams a client's workout history for the 운동 sub-tab.
final clientHistoryProvider =
    StreamProvider.family<List<RoutineHistoryEntry>, String>((ref, clientId) {
      return ref.watch(clientRepositoryProvider).watchHistory(clientId);
    });
