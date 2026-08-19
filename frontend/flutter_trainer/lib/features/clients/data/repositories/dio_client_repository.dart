import 'dart:async';

import 'package:dio/dio.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/active_polling_stream.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/clients/data/dtos/client_dtos.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
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
  DioClientRepository(this._dio);

  final Dio _dio;
  final StreamController<String?> _refreshes =
      StreamController<String?>.broadcast(sync: true);

  @override
  bool get supportsRosterMutations => false;

  @override
  Stream<List<TrainerClient>> watchClients() =>
      activePollingStream<List<TrainerClient>>(
        load: _fetchClients,
        interval: null,
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
        interval: null,
        refreshes: _refreshesFor(clientId),
      );

  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) =>
      activePollingStream<List<RoutineHistoryEntry>>(
        load: () => _fetchHistory(clientId),
        interval: null,
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
  Future<ClientExerciseWeek> fetchExerciseWeek(
    String clientId, {
    DateTime? weekStart,
  }) async {
    final path =
        '/trainer/clients/${Uri.encodeComponent(clientId)}/exercise-week';
    try {
      final response = await _dio.get<Map<String, Object?>>(
        path,
        queryParameters: weekStart == null
            ? null
            : <String, String>{'week_start': ymd(clientMondayOf(weekStart))},
      );
      return ClientExerciseWeek.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

  /// 일별 식단 집계를 **리포트 응답**에서 만든다.
  ///
  /// 끼니 목록(`/diet?date=`)을 날마다 부르면 한 달에 서른 번 넘게 오간다.
  /// 리포트는 한 주의 일별 칼로리·나트륨·당류를 한 번에 주므로, 한 달이라도
  /// 요청은 다섯 번 남짓이다. 두 경로 모두 같은 `diet_entries` 를 읽는다.
  @override
  Future<ClientDietPeriod> fetchDietPeriod(
    String clientId,
    ClientDateRange range,
  ) async {
    final Map<String, ClientDietDay> byDate = <String, ClientDietDay>{};
    for (final DateTime monday in clientRangeWeekStarts(range)) {
      final Map<String, Object?> week = await _fetchReportWeek(
        clientId,
        monday,
      );
      List<num> series(String key) =>
          ((week[key] as List<Object?>?) ?? const <Object?>[])
              .whereType<num>()
              .toList(growable: false);
      final List<num> calories = series('calories_week');
      final List<num> sodium = series('sodium_week');
      final List<num> sugar = series('sugar_week');
      for (var d = 0; d < 7; d++) {
        final DateTime date = DateTime(
          monday.year,
          monday.month,
          monday.day + d,
        );
        byDate[ymd(date)] = ClientDietDay(
          date: date,
          calories: d < calories.length ? calories[d].toInt() : 0,
          sodiumMg: d < sodium.length ? sodium[d].toInt() : 0,
          sugarG: d < sugar.length ? sugar[d].toDouble() : 0,
        );
      }
    }
    return ClientDietPeriod(
      range: range,
      days: <ClientDietDay>[
        for (final DateTime date in clientRangeDates(range))
          byDate[ymd(date)] ?? ClientDietDay(date: date),
      ],
    );
  }

  Future<Map<String, Object?>> _fetchReportWeek(
    String clientId,
    DateTime monday,
  ) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/trainer/clients/${Uri.encodeComponent(clientId)}/report',
        queryParameters: <String, String>{'week_start': ymd(monday)},
      );
      return response.data ?? const <String, Object?>{};
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
