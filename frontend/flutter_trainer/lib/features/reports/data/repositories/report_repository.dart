import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/reports/domain/report_summary.dart';
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

  /// [client] 의 [weekStart] 주 요약.
  ///
  /// 리포트 본문과 **따로** 가져온다. 실서버는 생성에 몇 초가 걸리는데 한
  /// 응답에 묶으면 고객을 고를 때마다 화면 전체가 그만큼 멈춘다(#755).
  Future<ReportSummary> summary({
    required TrainerClient client,
    required DateTime weekStart,
  });

  /// Sends [message] (defaults to the report's own body) to the member.
  Future<void> send({
    required String clientId,
    required DateTime weekStart,
    required String message,
  });

  /// [client] 의 [weekStart] 주에 저장해 둔 피드백 초안. (#821)
  ///
  /// 저장한 적이 없으면 [ReportFeedbackDraft.saved] 가 false 다 — 화면은 그때
  /// 자동 생성 문구를 쓴다. "저장한 적 없음" 과 "빈 문자열을 저장함" 은 서로
  /// 다르다: 뒤엣것은 트레이너가 일부러 지운 것이라 되살리면 안 된다.
  Future<ReportFeedbackDraft> feedbackDraft({
    required TrainerClient client,
    required DateTime weekStart,
  });

  /// 그 주의 피드백 초안을 [body] 로 통째로 바꾼다. (#821)
  Future<ReportFeedbackDraft> saveFeedbackDraft({
    required String clientId,
    required DateTime weekStart,
    required String body,
  });
}

/// 한 주에 저장돼 있는 피드백 초안.
class ReportFeedbackDraft {
  const ReportFeedbackDraft({required this.body, required this.saved});

  /// 저장된 적 없는 주. 화면은 자동 생성 문구로 시작한다.
  const ReportFeedbackDraft.none() : body = '', saved = false;

  final String body;

  /// 이 주에 저장 기록이 있는가. 빈 본문을 저장한 경우에도 true 다.
  final bool saved;
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

  @override
  Future<ReportSummary> summary({
    required TrainerClient client,
    required DateTime weekStart,
  }) async {
    // 데모에는 모델이 없다. 실서버가 공급자 장애에서 쓰는 것과 **같은** 규칙
    // 기반 요약을 쓴다 — 데모에서 본 문장이 실서버의 실패 화면과 같아진다.
    final report = await watch(client: client, weekStart: weekStart).first;
    return ruleReportSummary(report, client);
  }

  /// 저장된 운동 목록을 방어적으로 디코드. 깨진 값은 빈 목록으로.
  static List<String> _exercises(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const <String>[];
      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
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
      days: <ReportDay>[
        for (var d = 0; d < 7; d++)
          ReportDay(
            completion: on(d)?.completion ?? 0,
            exercises: _exercises(on(d)?.exercisesJson),
          ),
      ],
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

  @override
  Future<ReportFeedbackDraft> feedbackDraft({
    required TrainerClient client,
    required DateTime weekStart,
  }) async {
    final row =
        await (_db.select(_db.reportFeedbackDrafts)..where(
              (t) =>
                  t.clientId.equals(client.id) &
                  t.weekStart.equals(ymd(weekStartOf(weekStart))),
            ))
            .getSingleOrNull();
    if (row == null) return const ReportFeedbackDraft.none();
    return ReportFeedbackDraft(body: row.body, saved: true);
  }

  @override
  Future<ReportFeedbackDraft> saveFeedbackDraft({
    required String clientId,
    required DateTime weekStart,
    required String body,
  }) async {
    await _db
        .into(_db.reportFeedbackDrafts)
        .insertOnConflictUpdate(
          ReportFeedbackDraftsCompanion.insert(
            clientId: clientId,
            weekStart: ymd(weekStartOf(weekStart)),
            body: Value<String>(body),
            updatedAt: DateTime.now(),
          ),
        );
    return ReportFeedbackDraft(body: body, saved: true);
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
  Future<ReportSummary> summary({
    required TrainerClient client,
    required DateTime weekStart,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/trainer/clients/${Uri.encodeComponent(client.id)}/report/summary',
        queryParameters: <String, String>{'week_start': ymd(weekStart)},
      );
      final json = res.data;
      if (json == null) throw const ServerError();
      return ReportSummary(
        headline: (json['headline'] as String? ?? '').trim(),
        points: (json['points'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .toList(growable: false),
        generatedBy: json['generated_by'] as String? ?? 'rule',
      );
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

  @override
  Future<ReportFeedbackDraft> feedbackDraft({
    required TrainerClient client,
    required DateTime weekStart,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/trainer/clients/${Uri.encodeComponent(client.id)}/report/feedback',
        queryParameters: <String, String>{'week_start': ymd(weekStart)},
      );
      final json = res.data;
      if (json == null) throw const ServerError();
      return _draftFromJson(json);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<ReportFeedbackDraft> saveFeedbackDraft({
    required String clientId,
    required DateTime weekStart,
    required String body,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/trainer/clients/${Uri.encodeComponent(clientId)}/report/feedback',
        data: <String, String>{'week_start': ymd(weekStart), 'body': body},
      );
      final json = res.data;
      if (json == null) throw const ServerError();
      return _draftFromJson(json);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  /// `updated_at` 이 있으면 저장된 적이 있는 주다 — 빈 본문을 저장한 경우와
  /// 한 번도 쓰지 않은 경우를 이 값으로 가른다.
  static ReportFeedbackDraft _draftFromJson(Map<String, dynamic> json) {
    return ReportFeedbackDraft(
      body: json['body'] as String? ?? '',
      saved: json['updated_at'] != null,
    );
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
    days: <ReportDay>[
      for (final day in (json['days'] as List<Object?>? ?? const <Object?>[]))
        if (day is Map<String, dynamic>)
          ReportDay(
            completion: (day['completion'] as num?)?.toInt() ?? 0,
            exercises:
                (day['exercises'] as List<Object?>? ?? const <Object?>[])
                    .whereType<String>()
                    .toList(growable: false),
          ),
    ],
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

/// 그 주에 저장돼 있는 피드백 초안. (#821)
///
/// 리포트 본문·요약과 따로 부른다 — 초안은 트레이너가 쓰던 글이고, 리포트가
/// 다시 계산돼도 그 글이 사라지면 안 된다.
///
/// `autoDispose` 인 이유는 요약과 같다 — 고객·주를 옮겨 다니는 화면이라
/// 남겨 두면 본 적 있는 모든 주의 초안이 메모리에 쌓인다. 저장 뒤에는 이
/// provider 를 무효화해 다음 조회가 새 값을 읽게 한다.
final reportFeedbackDraftProvider =
    FutureProvider.autoDispose.family<ReportFeedbackDraft, ReportKey>((
      ref,
      key,
    ) {
      return ref
          .watch(reportRepositoryProvider)
          .feedbackDraft(client: key.client, weekStart: key.weekStart);
    });

/// 한 주의 리포트 요약. 리포트 본문과 따로 부른다(#755).
///
/// `autoDispose` 다 — 고객·주를 옮겨 다니는 화면이라 남겨 두면 본 적 있는 모든
/// 주의 요약이 메모리에 쌓인다. 다시 생성하려면 이 provider 를 무효화한다.
final reportSummaryProvider =
    FutureProvider.autoDispose.family<ReportSummary, ReportKey>((ref, key) {
      return ref
          .watch(reportRepositoryProvider)
          .summary(client: key.client, weekStart: key.weekStart);
    });
