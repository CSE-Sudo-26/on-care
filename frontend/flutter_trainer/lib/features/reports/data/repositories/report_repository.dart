import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';

/// Builds and delivers a client's weekly report.
///
/// Two sources sit behind this, chosen by [AppConfig.useMockApi]:
///
///  * [LocalReportRepository] — demo/drift. The report is computed from
///    the same local streams the rest of the app reads.
///  * [DioReportRepository] — the real backend aggregates it
///    (`GET /trainer/clients/{id}/report`), because the server owns the
///    member's full history; the client only ever sees this week.
///
/// Both deliver into the member's chat thread. A separate report inbox
/// would be a place members never open.
abstract interface class ReportRepository {
  /// The report for [client]'s week containing [weekStart].
  ///
  /// A stream, not a future, so the local source stays reactive: marking
  /// a session 완료 in another tab updates the report in place. The Dio
  /// source emits once (fetch → value), like the other API repositories.
  Stream<WeeklyReport> watch({
    required TrainerClient client,
    required DateTime weekStart,
  });

  /// Sends [message] (defaults to the report's own body) to the member.
  Future<void> send({
    required String clientId,
    required DateTime weekStart,
    required String message,
  });
}

/// Computes the report locally from the drift-backed streams.
class LocalReportRepository implements ReportRepository {
  /// Creates the local source.
  const LocalReportRepository(this._schedule, this._chat, this._db);

  final ScheduleRepository _schedule;
  final ChatRepository _chat;
  final AppDatabase _db;

  @override
  Stream<WeeklyReport> watch({
    required TrainerClient client,
    required DateTime weekStart,
  }) {
    final start = weekStartOf(weekStart);
    return _schedule
        .watchClientSessions((id: client.id, name: client.name))
        .asyncMap(
          (sessions) async => buildWeeklyReport(
            client: client,
            sessions: sessions,
            weekStart: start,
            // 데모도 그 주의 이력에서 계열을 만든다 — 로스터가 준 이번 주
            // 계열을 과거 주에 붙이지 않는다(#752).
            week: await _weekSeries(client.id, start),
          ),
        );
  }

  /// 그 주(월→일)의 요일별 값. 기록이 하나도 없으면 null — 화면이 "없다"고
  /// 말할 수 있어야 한다(0 으로 채우면 "하루 0kcal" 처럼 읽힌다).
  Future<WeekSeries?> _weekSeries(String clientId, DateTime monday) async {
    final sunday = monday.add(const Duration(days: 6));
    final rows =
        await (_db.select(_db.clientDailyMetrics)..where(
              (t) =>
                  t.clientId.equals(clientId) &
                  t.date.isBiggerOrEqualValue(ymd(monday)) &
                  t.date.isSmallerOrEqualValue(ymd(sunday)),
            ))
            .get();
    if (rows.isEmpty) return null;
    final byDate = <String, ClientDailyMetricRow>{
      for (final row in rows) row.date: row,
    };
    ClientDailyMetricRow? on(int day) =>
        byDate[ymd(monday.add(Duration(days: day)))];
    return WeekSeries(
      completion: <int>[for (var d = 0; d < 7; d++) on(d)?.completion ?? 0],
      sodium: <int>[for (var d = 0; d < 7; d++) on(d)?.sodiumMg ?? 0],
      calories: <int>[for (var d = 0; d < 7; d++) on(d)?.calories ?? 0],
      sugar: <double>[for (var d = 0; d < 7; d++) on(d)?.sugarG ?? 0],
    );
  }

  @override
  Future<void> send({
    required String clientId,
    required DateTime weekStart,
    required String message,
  }) {
    return _chat.sendTrainerMessage(clientId: clientId, text: message);
  }
}

/// Reads the report the backend aggregated, and posts the send there so
/// the server records it on the same thread the member app reads.
class DioReportRepository implements ReportRepository {
  /// Creates the API-backed source.
  const DioReportRepository(this._dio);

  final Dio _dio;

  @override
  Stream<WeeklyReport> watch({
    required TrainerClient client,
    required DateTime weekStart,
  }) {
    return Stream<WeeklyReport>.fromFuture(
      _fetch(client: client, weekStart: weekStart),
    );
  }

  Future<WeeklyReport> _fetch({
    required TrainerClient client,
    required DateTime weekStart,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/trainer/clients/${Uri.encodeComponent(client.id)}/report',
        queryParameters: <String, String>{'week_start': ymd(weekStart)},
      );
      final json = res.data;
      if (json == null) {
        // 문구는 화면이 붙인다 — 리포지토리는 로케일을 모른다. (#501)
        throw const ServerError();
      }
      return weeklyReportFromJson(json, client);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> send({
    required String clientId,
    required DateTime weekStart,
    required String message,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/trainer/clients/${Uri.encodeComponent(clientId)}/report/send',
        data: <String, String>{
          'week_start': ymd(weekStart),
          'message': message,
        },
      );
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }
}

/// Decodes `WeeklyReportOut`. 계열도 함께 온다 — 로스터의 것은 이번 주 것이라
/// 과거 주 화면에 쓸 수 없다(#752).
WeeklyReport weeklyReportFromJson(
  Map<String, dynamic> json,
  TrainerClient client,
) {
  int? optInt(String key) => (json[key] as num?)?.toInt();
  List<int> ints(String key) => (json[key] as List<Object?>? ?? const <Object?>[])
      .whereType<num>()
      .map((n) => n.toInt())
      .toList(growable: false);
  List<double> doubles(String key) =>
      (json[key] as List<Object?>? ?? const <Object?>[])
          .whereType<num>()
          .map((n) => n.toDouble())
          .toList(growable: false);
  final weekStart =
      DateTime.tryParse(json['week_start'] as String? ?? '') ??
      weekStartOf(DateTime.now());
  return WeeklyReport(
    client: client,
    weekStart: weekStart,
    isCurrentWeek: weekStartOf(weekStart) == weekStartOf(DateTime.now()),
    sessionsBooked: optInt('sessions_booked') ?? 0,
    sessionsDone: optInt('sessions_done') ?? 0,
    completionAvg: optInt('completion_avg'),
    sodiumOverDays: optInt('sodium_over_days') ?? 0,
    sodiumAvg: optInt('sodium_avg'),
    weekCompletion: ints('week_completion'),
    sodiumWeek: ints('sodium_week'),
    caloriesWeek: ints('calories_week'),
    sugarWeek: doubles('sugar_week'),
  );
}

/// Provides the [ReportRepository] for the current mode.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return LocalReportRepository(
      ref.watch(scheduleRepositoryProvider),
      ref.watch(chatRepositoryProvider),
      ref.watch(appDatabaseProvider),
    );
  }
  return DioReportRepository(ref.watch(dioProvider));
}, name: 'reportRepository');

/// Identifies one client's report week.
typedef ReportKey = ({TrainerClient client, DateTime weekStart});

/// Streams a client's weekly report.
final weeklyReportProvider = StreamProvider.family<WeeklyReport, ReportKey>((
  ref,
  key,
) {
  return ref
      .watch(reportRepositoryProvider)
      .watch(client: key.client, weekStart: key.weekStart);
});
