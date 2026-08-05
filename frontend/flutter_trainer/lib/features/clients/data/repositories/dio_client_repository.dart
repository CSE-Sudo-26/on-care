import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/dtos/client_dtos.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

/// Reads a trainer's clients + their diet/history from the FastAPI backend.
/// Selected when `USE_MOCK_API=false` (see [clientRepositoryProvider]).
///
/// Reads return single-emit streams (fetch → value); the consuming
/// `AsyncValue` renders loading/error/empty. Roster mutations have no
/// backend endpoint (the roster is derived from trainer↔member links), so
/// they throw [UnsupportedError] — the demo-only add/activate UI is hidden
/// in real-API mode.
class DioClientRepository implements ClientRepository {
  DioClientRepository(this._dio);

  final Dio _dio;

  @override
  bool get supportsRosterMutations => false;

  @override
  Stream<List<TrainerClient>> watchClients() =>
      Stream<List<TrainerClient>>.fromFuture(_fetchClients());

  /// The roster endpoint carries no chat-recency signal, so priority
  /// ordering falls back to the server's own order. Emitting an empty map
  /// (not nothing) lets the ordering resolve immediately.
  @override
  Stream<Map<String, DateTime>> watchLastChatAt() =>
      Stream<Map<String, DateTime>>.value(const <String, DateTime>{});

  /// Today's booked-session count is schedule-derived (a later issue wires
  /// `/trainer/schedule`). Emitting nothing keeps the header badge hidden
  /// (its provider stays loading → `valueOrNull` is null) rather than
  /// showing a stale/zero count over real clients.
  @override
  Stream<int> watchTodayReservationCount() => const Stream<int>.empty();

  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) =>
      Stream<List<ClientDietEntry>>.fromFuture(_fetchDiet(clientId));

  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) =>
      Stream<List<RoutineHistoryEntry>>.fromFuture(_fetchHistory(clientId));

  Future<List<TrainerClient>> _fetchClients() =>
      _getList('/trainer/clients', trainerClientFromJson);

  Future<List<ClientDietEntry>> _fetchDiet(String clientId) => _getList(
    '/trainer/clients/${Uri.encodeComponent(clientId)}/diet',
    clientDietEntryFromJson,
  );

  Future<List<RoutineHistoryEntry>> _fetchHistory(String clientId) => _getList(
    '/trainer/clients/${Uri.encodeComponent(clientId)}/history',
    routineHistoryEntryFromJson,
  );

  /// GETs a JSON array and maps each element with [fromJson]. Transport /
  /// HTTP failures (incl. 404 for a client that isn't this trainer's)
  /// surface as a typed [AppError].
  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, Object?>) fromJson,
  ) async {
    try {
      final res = await _dio.get<List<dynamic>>(path);
      final data = res.data ?? const <dynamic>[];
      return data
          .map((item) {
            if (item is! Map<String, Object?>) {
              throw FormatException(
                'Expected an object in the response list for $path.',
              );
            }
            return fromJson(item);
          })
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<bool> clientNameExists(String name) => throw UnsupportedError(
    'clientNameExists is demo-only (no backend endpoint).',
  );

  @override
  Future<bool> addClient({required String name, required String goal}) =>
      throw UnsupportedError('addClient is demo-only (no backend endpoint).');

  @override
  Future<void> setClientActive(String id, bool active) =>
      throw UnsupportedError(
        'setClientActive is demo-only (no backend endpoint).',
      );
}
