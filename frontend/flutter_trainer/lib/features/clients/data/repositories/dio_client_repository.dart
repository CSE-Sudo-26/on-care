import 'dart:async';

import 'package:dio/dio.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/active_polling_stream.dart';
import 'package:oncare_trainer/features/clients/data/dtos/client_dtos.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/features/clients/domain/repositories/client_data_refresher.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

/// Reads a trainer's clients + their diet/history from the FastAPI backend.
/// Selected when `USE_MOCK_API=false` (see [clientRepositoryProvider]).
///
/// Reads revalidate when their screen subscribes and when the app/browser
/// returns to the foreground. Roster mutations have no
/// backend endpoint (the roster is derived from trainer↔member links), so
/// they throw [UnsupportedError] — the demo-only add/activate UI is hidden
/// in real-API mode.
class DioClientRepository implements ClientRepository, ClientDataRefresher {
  DioClientRepository(
    this._dio, {
    this.pollInterval = const Duration(seconds: 30),
  });

  final Dio _dio;

  /// 명단과 그 회원의 기록을 다시 읽는 주기.
  ///
  /// 회원이 식단 사진을 올리거나 운동을 마치는 것은 트레이너가 누르는 일이
  /// 아니라, 여기서 따라잡지 않으면 옆에 띄워 둔 화면이 낡은 값을 계속
  /// 보여 준다 — 코칭은 그 값을 보면서 하는 일이라 값이 낡으면 판단이
  /// 낡는다(#918). 채팅(3초)만큼 잦을 이유는 없다. 기록은 초 단위가 아니라
  /// 분 단위로 쌓인다.
  final Duration pollInterval;

  final StreamController<String?> _refreshes =
      StreamController<String?>.broadcast(sync: true);

  @override
  bool get supportsRosterMutations => false;

  @override
  Stream<List<TrainerClient>> watchClients() =>
      activePollingStream<List<TrainerClient>>(
        load: _fetchClients,
        interval: pollInterval,
        refreshes: _refreshesFor(null),
      );

  /// The roster endpoint carries no chat-recency signal, so priority
  /// ordering falls back to the server's own order. Emitting an empty map
  /// (not nothing) lets the ordering resolve immediately.
  @override
  Stream<Map<String, DateTime>> watchLastChatAt() =>
      Stream<Map<String, DateTime>>.value(const <String, DateTime>{});

  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) =>
      activePollingStream<List<ClientDietEntry>>(
        load: () => _fetchDiet(clientId),
        interval: pollInterval,
        refreshes: _refreshesFor(clientId),
      );

  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) =>
      activePollingStream<List<RoutineHistoryEntry>>(
        load: () => _fetchHistory(clientId),
        interval: pollInterval,
        refreshes: _refreshesFor(clientId),
      );

  Stream<void> _refreshesFor(String? clientId) => _refreshes.stream
      .where(
        (String? target) =>
            target == null || clientId == null || target == clientId,
      )
      .map((_) {});

  @override
  void refreshAllClientData() => _refreshes.add(null);

  @override
  void refreshClientData(String clientId) => _refreshes.add(clientId);

  @override
  Future<ClientExerciseWeek> fetchExerciseWeek(String clientId) async {
    final path =
        '/trainer/clients/${Uri.encodeComponent(clientId)}/exercise-week';
    try {
      final response = await _dio.get<Map<String, Object?>>(path);
      return ClientExerciseWeek.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

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

  @override
  Future<RoutineHistoryEntry> updateHistoryFeedback(
    String clientId,
    String historyId,
    String feedback,
  ) async {
    final String path =
        '/trainer/clients/${Uri.encodeComponent(clientId)}/history/'
        '${Uri.encodeComponent(historyId)}/feedback';
    try {
      final Response<Map<String, Object?>> response = await _dio.put(
        path,
        data: <String, Object?>{'feedback': feedback.trim()},
      );
      final Map<String, Object?>? data = response.data;
      if (data == null) throw const FormatException('Missing history row.');
      return routineHistoryEntryFromJson(data);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

  @override
  Future<MemberHealthProfile> fetchHealthProfile(String clientId) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/trainer/clients/${Uri.encodeComponent(clientId)}/health-profile',
      );
      return MemberHealthProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

  @override
  Future<MemberHealthProfile> updateHealthProfile(
    String clientId,
    Map<String, Object?> values,
  ) async {
    try {
      final response = await _dio.put<Map<String, Object?>>(
        '/trainer/clients/${Uri.encodeComponent(clientId)}/health-profile',
        data: values,
      );
      return MemberHealthProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

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

  /// Flips the trainer's 활성/휴면 management state for [id] (#707).
  ///
  /// This is not an unassignment — the backend keeps the trainer↔member link
  /// and every record behind it, and the member app sees no change.
  ///
  /// The roster is re-fetched only after the server confirms, so a failed
  /// call leaves the badge showing the last state the server actually has.
  @override
  Future<void> setClientActive(String id, bool active) async {
    try {
      await _dio.put<Map<String, Object?>>(
        '/trainer/clients/${Uri.encodeComponent(id)}/status',
        data: <String, Object?>{'active': active},
      );
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
    _refreshes.add(id);
  }
}
