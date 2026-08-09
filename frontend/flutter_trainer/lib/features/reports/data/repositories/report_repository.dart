import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
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
  const LocalReportRepository(this._schedule, this._chat);

  final ScheduleRepository _schedule;
  final ChatRepository _chat;

  @override
  Stream<WeeklyReport> watch({
    required TrainerClient client,
    required DateTime weekStart,
  }) {
    return _schedule
        .watchClientSessions((id: client.id, name: client.name))
        .map(
          (sessions) => buildWeeklyReport(
            client: client,
            sessions: sessions,
            weekStart: weekStart,
          ),
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

/// Decodes `WeeklyReportOut`. [client] carries the chart series, which the
/// report endpoint doesn't repeat (the roster already delivered them).
WeeklyReport weeklyReportFromJson(
  Map<String, dynamic> json,
  TrainerClient client,
) {
  int? optInt(String key) => (json[key] as num?)?.toInt();
  final weekStart =
      DateTime.tryParse(json['week_start'] as String? ?? '') ??
      weekStartOf(DateTime.now());
  return WeeklyReport(
    client: client,
    weekStart: weekStart,
    // [client]'s weekday series describes the current week only, so the
    // report has to say which week it is before anything renders them.
    isCurrentWeek: weekStartOf(weekStart) == weekStartOf(DateTime.now()),
    sessionsBooked: optInt('sessions_booked') ?? 0,
    sessionsDone: optInt('sessions_done') ?? 0,
    completionAvg: optInt('completion_avg'),
    sodiumOverDays: optInt('sodium_over_days') ?? 0,
    sodiumAvg: optInt('sodium_avg'),
  );
}

/// Provides the [ReportRepository] for the current mode.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return LocalReportRepository(
      ref.watch(scheduleRepositoryProvider),
      ref.watch(chatRepositoryProvider),
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
