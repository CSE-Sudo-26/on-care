import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_chat_repository.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';

/// Reads and sends messages in a trainer↔member chat thread.
///
/// Two implementations sit behind this contract (selected by
/// [chatRepositoryProvider] via [AppConfig.useMockApi]):
///  * [DriftChatRepository] — local drift, demo / `USE_MOCK_API=true`;
///  * [DioChatRepository] — the real FastAPI backend (thread shared with
///    the member app).
///
/// The drift source is reactive (streams re-emit on write); the Dio source
/// emits a single fetch, so callers invalidate the thread/unread providers
/// after send/read (see [ChatView]).
abstract interface class ChatRepository {
  Stream<List<ClientChatMessage>> watchThread(String clientId);
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  });
  Stream<Map<String, int>> watchUnreadCounts();
  Future<void> markThreadRead(String clientId);
}

/// Reads and appends messages in a client's chat thread (drift-backed).
class DriftChatRepository implements ChatRepository {
  /// Creates the repository over [_db].
  const DriftChatRepository(this._db);

  final AppDatabase _db;

  /// Streams a client's messages in chronological order.
  @override
  Stream<List<ClientChatMessage>> watchThread(String clientId) {
    final query = _db.select(_db.clientChatMessages)
      ..where((t) => t.clientId.equals(clientId))
      ..orderBy(<OrderingTerm Function($ClientChatMessagesTable)>[
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// Appends a trainer message and refreshes the client's list-card
  /// preview (`lastMessage`/`lastTime`) in one transaction. The `chat-`
  /// id (no `seed-` prefix) means it survives re-seeding, and `now()`
  /// sorts it after the seed thread.
  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db
          .into(_db.clientChatMessages)
          .insert(
            ClientChatMessagesCompanion.insert(
              id: 'chat-$clientId-${now.microsecondsSinceEpoch}',
              clientId: clientId,
              sender: 'trainer',
              body: trimmed,
              timeLabel: _timeLabel(now),
              createdAt: now,
            ),
          );
      await (_db.update(
        _db.trainerClients,
      )..where((t) => t.id.equals(clientId))).write(
        TrainerClientsCompanion(
          lastMessage: Value(trimmed),
          lastTime: const Value('방금'),
        ),
      );
    });
  }

  /// Per-client unread counts — client-sent messages after the trainer's
  /// last-read marker (an `AppKeyValues` row per client, so no schema
  /// migration). Clients with zero unread are absent.
  @override
  Stream<Map<String, int>> watchUnreadCounts() {
    // The marker is a monotonic `rowid`, not an epoch second: two client
    // messages that land in the same second share a `created_at` value,
    // so a timestamp marker can't tell them apart — after reading the
    // first, the second would look already-read. `rowid` is unique and
    // increasing, so it distinguishes same-second messages (review 241).
    final query = _db.customSelect(
      'SELECT m.client_id AS cid, COUNT(*) AS cnt '
      'FROM client_chat_messages m '
      "LEFT JOIN app_key_values k ON k.\"key\" = '$_readKeyPrefix' || m.client_id "
      "WHERE m.sender = 'client' "
      'AND (k.value IS NULL OR m.rowid > CAST(k.value AS INTEGER)) '
      'GROUP BY m.client_id',
      readsFrom: <ResultSetImplementation<Object?, Object?>>{
        _db.clientChatMessages,
        _db.appKeyValues,
      },
    );
    return query.watch().map(
      (rows) => <String, int>{
        for (final row in rows) row.read<String>('cid'): row.read<int>('cnt'),
      },
    );
  }

  /// Marks a client's thread read up to its newest client message.
  ///
  /// Idempotent and write-free when there is nothing new: the marker is
  /// the newest client message's `rowid` (not `now()`), so calling this
  /// again with no new messages computes the same value and skips the
  /// write entirely. That matters because `watchUnreadCounts` watches
  /// `app_key_values` — an unconditional write would emit on that stream
  /// and rebuild the list on every call (review PR 241).
  @override
  Future<void> markThreadRead(String clientId) async {
    final row =
        await _db
            .customSelect(
              'SELECT MAX(rowid) AS r FROM client_chat_messages '
              "WHERE client_id = ?1 AND sender = 'client'",
              variables: <Variable<Object>>[Variable<String>(clientId)],
              readsFrom: <ResultSetImplementation<Object?, Object?>>{
                _db.clientChatMessages,
              },
            )
            .getSingleOrNull();
    // MAX over no client message returns NULL — nothing could be unread.
    final marker = row?.read<int?>('r');
    if (marker == null) return;

    final key = '$_readKeyPrefix$clientId';
    final stored = int.tryParse(await _db.readValue(key) ?? '');
    if (stored != null && stored >= marker) return; // already read

    await _db.putValue(key, '$marker');
  }

  static const String _readKeyPrefix = 'chat_read_';

  ClientChatMessage _toEntity(ClientChatMessageRow row) {
    return ClientChatMessage(
      id: row.id,
      sender: row.sender == 'trainer' ? ChatSender.trainer : ChatSender.client,
      body: row.body,
      timeLabel: row.timeLabel,
      createdAt: row.createdAt,
    );
  }

  static String _timeLabel(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Provides the [ChatRepository]: the real Dio-backed source (thread shared
/// with the member app) or the local drift source for demo / `USE_MOCK_API`.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockApi) {
    return DriftChatRepository(ref.watch(appDatabaseProvider));
  }
  return DioChatRepository(ref.watch(dioProvider));
});

/// Streams per-client unread message counts for the 고객 list badges.
final unreadCountsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(chatRepositoryProvider).watchUnreadCounts();
});

/// Streams a client's chat thread by client id.
final chatThreadProvider =
    StreamProvider.family<List<ClientChatMessage>, String>((ref, clientId) {
      return ref.watch(chatRepositoryProvider).watchThread(clientId);
    });
