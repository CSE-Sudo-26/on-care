import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Reads client + schedule data from the local drift DB for the
/// 고객 관리 tab. Returns reactive streams so the UI updates if the
/// underlying rows change (e.g. a routine sent from another tab).
class ClientRepository {
  /// Creates the repository over [_db].
  const ClientRepository(this._db);

  final AppDatabase _db;

  /// All clients, ordered as seeded (sortOrder).
  Stream<List<TrainerClient>> watchClients() {
    final query = _db.select(_db.trainerClients)
      ..orderBy(<OrderingTerm Function($TrainerClientsTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// Clients ordered by coaching priority for the 고객 관리 list:
  /// sodium-over-target clients first, ties broken by the most recent
  /// chat activity, then by the seeded order.
  Stream<List<TrainerClient>> watchClientsPrioritized() {
    final t = _db.trainerClients;
    final chat = _db.clientChatMessages;
    final lastChatAt = chat.createdAt.max();
    final query =
        _db.select(t).join(<Join>[
            leftOuterJoin(
              chat,
              chat.clientId.equalsExp(t.id),
              useColumns: false,
            ),
          ])
          ..addColumns(<Expression<Object>>[lastChatAt])
          ..groupBy(<Expression<Object>>[t.id]);
    return query.watch().map((rows) {
      final entries = rows.map((r) {
        final row = r.readTable(t);
        return (
          client: _toEntity(row),
          lastChatAt: r.read(lastChatAt),
          sortOrder: row.sortOrder,
        );
      }).toList();
      entries.sort((a, b) {
        final over = (b.client.sodiumOverBudget ? 1 : 0).compareTo(
          a.client.sodiumOverBudget ? 1 : 0,
        );
        if (over != 0) return over;
        final chatCmp = (b.lastChatAt ?? DateTime.utc(1970)).compareTo(
          a.lastChatAt ?? DateTime.utc(1970),
        );
        if (chatCmp != 0) return chatCmp;
        return a.sortOrder.compareTo(b.sortOrder);
      });
      return entries.map((e) => e.client).toList();
    });
  }

  /// Count of today's booked sessions — every schedule slot dated today
  /// that isn't a gap (`공백`). Drives the "오늘 N명 예약" header badge.
  /// Uses a SQL `COUNT(*)` aggregate rather than loading every row.
  Stream<int> watchTodayReservationCount() {
    final today = ymd(DateTime.now());
    final table = _db.trainerScheduleEntries;
    final count = countAll();
    final query = _db.selectOnly(table)
      ..addColumns(<Expression<Object>>[count])
      ..where(table.date.equals(today) & table.status.equals('공백').not());
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// A client's meals for the 식단 sub-tab, in seeded order (아침 → 저녁).
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
            ),
          )
          .toList(),
    );
  }

  /// A client's workout history for the 운동기록 sub-tab, newest first
  /// (seeded order).
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
      lastRoutine: row.lastRoutine,
      weekCompletion: week,
    );
  }
}

/// Provides the [ClientRepository] wired to the app database.
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(appDatabaseProvider));
});

/// Streams the client list for the 고객 관리 tab.
final clientsProvider = StreamProvider<List<TrainerClient>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients();
});

/// Streams the coaching-priority ordering of the client list (sodium
/// over-target first, then most recent chat) for the 고객 관리 tab.
final prioritizedClientsProvider = StreamProvider<List<TrainerClient>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClientsPrioritized();
});

/// Streams today's booked-session count for the header badge.
final todayReservationCountProvider = StreamProvider<int>((ref) {
  return ref.watch(clientRepositoryProvider).watchTodayReservationCount();
});

/// Streams a client's meals for the 식단 sub-tab.
final clientDietProvider = StreamProvider.family<List<ClientDietEntry>, String>(
  (ref, clientId) {
    return ref.watch(clientRepositoryProvider).watchDiet(clientId);
  },
);

/// Streams a client's workout history for the 운동기록 sub-tab.
final clientHistoryProvider =
    StreamProvider.family<List<RoutineHistoryEntry>, String>((ref, clientId) {
      return ref.watch(clientRepositoryProvider).watchHistory(clientId);
    });
