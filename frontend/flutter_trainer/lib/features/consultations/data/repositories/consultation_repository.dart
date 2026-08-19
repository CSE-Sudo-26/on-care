import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/utils/active_polling_stream.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/features/consultations/data/dtos/consultation_dtos.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

/// Reads the trainer's consultation inbox and decides requests.
///
/// Two implementations, selected by [consultationRepositoryProvider] via
/// [AppConfig.useMockApi]:
///  * [DemoConsultationRepository] — demo / `USE_MOCK_API=true`. The demo
///    has no member backend to receive requests from, and its roster is
///    seeded, so the inbox is empty and the sidebar row is hidden. The
///    demo screens stay exactly as they are.
///  * [DioConsultationRepository] — the real backend, where accepting is
///    what creates the trainer↔member link.
abstract interface class ConsultationRepository {
  /// Whether this build can actually receive and decide requests.
  ///
  /// Drives whether the 상담 요청 destination appears at all — a dead nav
  /// row that always says "요청이 없어요" is worse than no row.
  bool get supportsInbox;

  /// Pending requests, newest first. `status` may be `pending` or `all`.
  Future<List<ConsultationRequest>> fetch({String status = 'pending'});

  /// Subscribes to the inbox for [status] — the open screen keeps up with
  /// requests that arrive while the trainer is looking at it. (#917)
  Stream<List<ConsultationRequest>> watch({String status = 'pending'});

  /// Number of undecided requests — the sidebar badge.
  Future<int> pendingCount();

  /// Subscribes to the badge count. Without this the badge stays at the
  /// number it was first given until the trainer opens the inbox. (#917)
  Stream<int> watchPendingCount();

  /// Accepts [id], creating the trainer↔member link server-side.
  Future<void> accept(String id, {ConsultationSchedule? schedule});

  /// Rejects [id]. [note] is delivered to the member as the reason.
  Future<void> reject(String id, {String? note});
}

/// Calendar values submitted together with an approval.
class ConsultationSchedule {
  const ConsultationSchedule({
    required this.date,
    required this.time,
    required this.type,
    required this.durationMinutes,
  });

  final String date;
  final String time;
  final String type;
  final int durationMinutes;
}

/// Demo build: no inbox. Reads succeed with nothing so any consumer that
/// does run (tests, a deep link) renders an empty state instead of an
/// error, and decisions are refused rather than silently doing nothing.
class DemoConsultationRepository implements ConsultationRepository {
  /// Creates the demo source.
  DemoConsultationRepository({List<ConsultationRequest>? requests})
    : _requests =
          requests ??
          <ConsultationRequest>[
            ConsultationRequest(
              id: 'demo-consultation-1',
              memberId: 'demo-consult-member-1',
              memberName: '김하늘',
              goalCode: 'fitness',
              purposeCode: 'general',
              preferredDate: nowKst().add(const Duration(days: 1)),
              preferredTimeCode: 'evening',
              status: 'pending',
              message: '퇴근 후 가능한 시간으로 첫 상담을 받고 싶어요.',
            ),
          ];

  List<ConsultationRequest> _requests;

  @override
  bool get supportsInbox => true;

  @override
  Future<List<ConsultationRequest>> fetch({String status = 'pending'}) async =>
      status == 'all'
      ? List<ConsultationRequest>.unmodifiable(_requests)
      : _requests.where((request) => request.status == status).toList();

  /// 데모의 인박스는 메모리에 있다. 폴링해도 같은 값을 다시 세는 것뿐이라
  /// 한 번 내고 끝내고, 수락·거절 뒤의 갱신은 지금처럼 invalidate 가 맡는다.
  @override
  Stream<List<ConsultationRequest>> watch({String status = 'pending'}) =>
      Stream<List<ConsultationRequest>>.fromFuture(fetch(status: status));

  @override
  Future<int> pendingCount() async =>
      _requests.where((request) => request.isPending).length;

  @override
  Stream<int> watchPendingCount() => Stream<int>.fromFuture(pendingCount());

  @override
  Future<void> accept(String id, {ConsultationSchedule? schedule}) async {
    _decide(id, 'accepted');
  }

  @override
  Future<void> reject(String id, {String? note}) async {
    _decide(id, 'rejected', note: note);
  }

  void _decide(String id, String status, {String? note}) {
    final index = _requests.indexWhere((request) => request.id == id);
    if (index < 0 || !_requests[index].isPending) {
      throw const ValidationError();
    }
    final request = _requests[index];
    _requests = <ConsultationRequest>[
      ..._requests.take(index),
      ConsultationRequest(
        id: request.id,
        memberId: request.memberId,
        memberName: request.memberName,
        goalCode: request.goalCode,
        purposeCode: request.purposeCode,
        preferredDate: request.preferredDate,
        preferredTimeCode: request.preferredTimeCode,
        status: status,
        message: request.message,
        purposeDetail: request.purposeDetail,
        decisionNote: note,
      ),
      ..._requests.skip(index + 1),
    ];
  }
}

/// Real backend: `/trainer/consultations`.
class DioConsultationRepository implements ConsultationRepository {
  /// Creates the API-backed repository.
  const DioConsultationRepository(
    this._dio, {
    this.pollInterval = badgePollInterval,
  });

  final Dio _dio;

  /// 인박스와 그 배지를 다시 읽는 주기. 같은 값을 쓰는 이유는 알림함과 같다 —
  /// 목록을 열어 둔 채 배지만 올라가면 두 숫자가 어긋나 보인다.
  final Duration pollInterval;

  @override
  bool get supportsInbox => true;

  @override
  Future<List<ConsultationRequest>> fetch({String status = 'pending'}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/trainer/consultations',
        queryParameters: <String, Object?>{'status': status},
      );
      return (res.data ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .map(consultationRequestFromJson)
          .toList();
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Stream<List<ConsultationRequest>> watch({String status = 'pending'}) =>
      activePollingStream<List<ConsultationRequest>>(
        load: () => fetch(status: status),
        interval: pollInterval,
      );

  @override
  Stream<int> watchPendingCount() =>
      activePollingStream<int>(load: pendingCount, interval: pollInterval);

  @override
  Future<int> pendingCount() async {
    try {
      final res = await _dio.get<Map<String, Object?>>(
        '/trainer/consultations/pending-count',
      );
      final count = res.data?['count'];
      return count is int ? count : 0;
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> accept(String id, {ConsultationSchedule? schedule}) =>
      _decide(id, 'accept', null, schedule: schedule);

  @override
  Future<void> reject(String id, {String? note}) => _decide(id, 'reject', note);

  /// Both decisions share their failure modes, so they share the mapping.
  ///
  /// 409 carries the server's own reason — already decided, or the member
  /// already has another trainer. That sentence is exactly what the
  /// trainer needs, so it is surfaced instead of a generic network error.
  Future<void> _decide(
    String id,
    String action,
    String? note, {
    ConsultationSchedule? schedule,
  }) async {
    try {
      await _dio.post<Map<String, Object?>>(
        '/trainer/consultations/${Uri.encodeComponent(id)}/$action',
        data: <String, Object?>{
          'note': note,
          if (schedule != null) ...<String, Object?>{
            'date': schedule.date,
            'time': schedule.time,
            'type': schedule.type,
            'duration_minutes': schedule.durationMinutes,
          },
        },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409 || status == 400 || status == 422) {
        throw ValidationError(message: _detail(e));
      }
      throw AppError.fromDio(e);
    }
  }

  String? _detail(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final detail = data['detail'];
    return detail is String ? detail : null;
  }
}

/// Provides the inbox source for the current mode.
final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return DemoConsultationRepository();
  }
  return DioConsultationRepository(ref.watch(dioProvider));
}, name: 'consultationRepository');

/// Whether the console shows the 상담 요청 destination at all.
final consultationInboxEnabledProvider = Provider<bool>(
  (ref) => ref.watch(consultationRepositoryProvider).supportsInbox,
  name: 'consultationInboxEnabled',
);

/// Current inbox filter — `pending` (default) or `all`.
final consultationFilterProvider = StateProvider<String>(
  (ref) => 'pending',
  name: 'consultationFilter',
);

/// The inbox list for the active filter.
final consultationsProvider =
    StreamProvider.autoDispose<List<ConsultationRequest>>((ref) {
      final status = ref.watch(consultationFilterProvider);
      return ref.watch(consultationRepositoryProvider).watch(status: status);
    }, name: 'consultations');

/// Pending count for the sidebar badge.
///
/// Its own request rather than `consultationsProvider.length`: the badge
/// must stay correct while the trainer is looking at the `all` filter, and
/// it is read from the sidebar on every page.
final consultationPendingCountProvider = StreamProvider.autoDispose<int>((ref) {
  if (!ref.watch(consultationInboxEnabledProvider)) {
    return Stream<int>.value(0);
  }
  return ref.watch(consultationRepositoryProvider).watchPendingCount();
}, name: 'consultationPendingCount');

/// Accepts a request and refreshes everything it changed.
///
/// The roster is invalidated too — accepting is precisely the moment a new
/// client appears, and a stale 고객 tab would make the trainer wonder
/// whether the approval worked.
Future<void> acceptConsultation(
  WidgetRef ref,
  String id, {
  ConsultationSchedule? schedule,
}) async {
  await ref.read(consultationRepositoryProvider).accept(id, schedule: schedule);
  _refreshAfterDecision(ref);
  ref.invalidate(clientsProvider);
}

/// Rejects a request. The roster is untouched, so it is not invalidated.
Future<void> rejectConsultation(
  WidgetRef ref,
  String id, {
  String? note,
}) async {
  await ref.read(consultationRepositoryProvider).reject(id, note: note);
  _refreshAfterDecision(ref);
}

void _refreshAfterDecision(WidgetRef ref) {
  ref.invalidate(consultationsProvider);
  ref.invalidate(consultationPendingCountProvider);
}
