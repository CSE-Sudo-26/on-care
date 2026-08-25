import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/utils/active_polling_stream.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/features/consultations/data/dtos/consultation_dtos.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
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
  ///
  /// 서버가 한 쪽만 준다(#980). 더 오래된 요청은 받은 마지막 요청의 `createdAt`·`id` 를
  /// [before]·[beforeId] 로 넘겨 이어 받는다.
  Future<List<ConsultationRequest>> fetch({
    String status = 'pending',
    int limit,
    DateTime? before,
    String? beforeId,
  });

  /// Subscribes to the inbox for [status] — the open screen keeps up with
  /// requests that arrive while the trainer is looking at it. (#917)
  ///
  /// **첫 쪽만** 흘려보낸다. 이어 받아 둔 과거 요청까지 매번 다시 읽으면 폴링이
  /// 인박스 길이에 비례해 무거워진다 — 과거 요청은 바뀌지 않으므로 한 번 받으면 된다.
  Stream<List<ConsultationRequest>> watch({
    String status = 'pending',
    int limit,
  });

  /// Number of undecided requests — the sidebar badge.
  Future<int> pendingCount();

  /// Subscribes to the badge count. Without this the badge stays at the
  /// number it was first given until the trainer opens the inbox. (#917)
  Stream<int> watchPendingCount();

  /// Accepts [id], creating the trainer↔member link server-side.
  Future<ConsultationAcceptResult> accept(
    String id, {
    ConsultationSchedule? schedule,
  });

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

/// 서버와 데모 저장소가 공통으로 돌려주는 승인 결과.
class ConsultationAcceptResult {
  const ConsultationAcceptResult({
    required this.clientConnected,
    required this.scheduleCreated,
    this.scheduleId,
  });

  final bool clientConnected;
  final bool scheduleCreated;
  final String? scheduleId;
}

/// 승인하려는 시간이 트레이너의 다른 일정과 겹친다 — 서버가 아무것도
/// 만들지 않고 409 로 막았다. [schedule_recurrence.dart] 의
/// `ScheduleSeriesConflictError` 와 같은 자리다: `AppError` 계열이 아니라
/// 따로 잡아, 다른 409(이미 처리됨 등)와 섞이지 않고 버튼 옆에 인라인으로
/// 보일 수 있게 한다.
class ConsultationScheduleConflictError implements Exception {
  const ConsultationScheduleConflictError({
    required this.clientName,
    required this.time,
  });

  /// 그 시간을 이미 차지하고 있는 세션의 고객 이름("신규 회원" 등 표시용
  /// 값 포함).
  final String clientName;

  /// 겹친 세션의 시작 시각(`HH:mm`).
  final String time;
}

/// Demo build: no inbox. Reads succeed with nothing so any consumer that
/// does run (tests, a deep link) renders an empty state instead of an
/// error, and decisions are refused rather than silently doing nothing.
class DemoConsultationRepository implements ConsultationRepository {
  /// Creates the demo source.
  DemoConsultationRepository({
    List<ConsultationRequest>? requests,
    ScheduleRepository Function()? scheduleRepository,
  }) : _scheduleRepository = scheduleRepository,
       _requests =
           requests ??
           <ConsultationRequest>[
             ConsultationRequest(
               id: 'demo-consultation-1',
               memberId: 'demo-consult-member-1',
               memberName: '김하늘',
               goalCode: 'fitness',
               purposeCode: 'general',
               preferredDate: nowKst().add(const Duration(days: 1)),
               // 사용자 앱은 시작–종료 범위로 희망 시간을 받는다(#1256) — 시드도
               // 그 형태를 따라야 트레이너 화면에서 종료 시각까지 보인다.
               preferredTimeCode: '19:00-20:00',
               status: 'pending',
               message: '퇴근 후 가능한 시간으로 첫 상담을 받고 싶어요.',
             ),
           ];

  List<ConsultationRequest> _requests;
  final ScheduleRepository Function()? _scheduleRepository;

  @override
  bool get supportsInbox => true;

  @override
  Future<List<ConsultationRequest>> fetch({
    String status = 'pending',
    int limit = consultationPageSize,
    DateTime? before,
    String? beforeId,
  }) async {
    // 데모 인박스는 한 줌이라 커서가 실제로 쓰일 일이 없다 — 상한만 지킨다.
    if (before != null) return const <ConsultationRequest>[];
    final Iterable<ConsultationRequest> rows = status == 'all'
        ? _requests
        : _requests.where((request) => request.status == status);
    return List<ConsultationRequest>.unmodifiable(rows.take(limit));
  }

  /// 데모의 인박스는 메모리에 있다. 폴링해도 같은 값을 다시 세는 것뿐이라
  /// 한 번 내고 끝내고, 수락·거절 뒤의 갱신은 지금처럼 invalidate 가 맡는다.
  @override
  Stream<List<ConsultationRequest>> watch({
    String status = 'pending',
    int limit = consultationPageSize,
  }) => Stream<List<ConsultationRequest>>.fromFuture(
    fetch(status: status, limit: limit),
  );

  @override
  Future<int> pendingCount() async =>
      _requests.where((request) => request.isPending).length;

  @override
  Stream<int> watchPendingCount() => Stream<int>.fromFuture(pendingCount());

  @override
  Future<ConsultationAcceptResult> accept(
    String id, {
    ConsultationSchedule? schedule,
  }) async {
    final index = _requests.indexWhere((request) => request.id == id);
    if (index < 0 || !_requests[index].isPending) {
      throw const ValidationError();
    }
    final request = _requests[index];
    if (schedule != null && _scheduleRepository != null) {
      final repository = _scheduleRepository();
      final sessions = await repository.watchDate(schedule.date).first;
      final start = _minutes(schedule.time);
      final end = start + schedule.durationMinutes;
      for (final session in sessions) {
        if (session.status == ScheduleStatus.gap) continue;
        final existingStart = _minutes(session.time);
        final existingEnd = existingStart + session.durationMinutes;
        if (start < existingEnd && existingStart < end) {
          throw ConsultationScheduleConflictError(
            clientName: session.clientName,
            time: session.time,
          );
        }
      }
      await repository.addSession(
        date: schedule.date,
        clientName: request.memberName,
        clientId: request.memberId,
        time: schedule.time,
        type: schedule.type,
        durationMinutes: schedule.durationMinutes,
        note: request.message ?? '',
      );
    }
    _decide(id, 'accepted');
    return ConsultationAcceptResult(
      clientConnected: true,
      scheduleCreated: schedule != null && _scheduleRepository != null,
    );
  }

  int _minutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
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
  Future<List<ConsultationRequest>> fetch({
    String status = 'pending',
    int limit = consultationPageSize,
    DateTime? before,
    String? beforeId,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/trainer/consultations',
        queryParameters: <String, Object?>{
          'status': status,
          'limit': limit,
          // 커서는 서버가 준 시각 그대로여야 한다 — 엔티티는 로컬 시각을 들고 있다.
          if (before != null) 'before': before.toUtc().toIso8601String(),
          'before_id': ?beforeId,
        },
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
  Stream<List<ConsultationRequest>> watch({
    String status = 'pending',
    int limit = consultationPageSize,
  }) => activePollingStream<List<ConsultationRequest>>(
    load: () => fetch(status: status, limit: limit),
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
  Future<ConsultationAcceptResult> accept(
    String id, {
    ConsultationSchedule? schedule,
  }) async {
    final data = await _decide(id, 'accept', null, schedule: schedule);
    return ConsultationAcceptResult(
      clientConnected: data['client_connected'] == true,
      scheduleCreated: data['schedule_created'] == true,
      scheduleId: data['schedule_id'] as String?,
    );
  }

  @override
  Future<void> reject(String id, {String? note}) async {
    await _decide(id, 'reject', note);
  }

  /// Both decisions share their failure modes, so they share the mapping.
  ///
  /// 409 carries the server's own reason — already decided, or the member
  /// already has another trainer. That sentence is exactly what the
  /// trainer needs, so it is surfaced instead of a generic network error.
  Future<Map<String, Object?>> _decide(
    String id,
    String action,
    String? note, {
    ConsultationSchedule? schedule,
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
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
      return response.data ?? const <String, Object?>{};
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (action == 'accept' && status == 409) {
        final conflict = _scheduleConflict(e);
        if (conflict != null) throw conflict;
      }
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

  /// `consultation_service.ConsultationScheduleConflict` 이 만드는 409 몸통 —
  /// 반복 생성 겹침(`{"message": ..., "conflicts": [...]}`)과 같은 모양이다.
  /// `detail` 이 문자열이면(다른 409) `null` 을 돌려 일반 경로로 넘긴다.
  ConsultationScheduleConflictError? _scheduleConflict(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is! Map) return null;
    final conflicts = detail['conflicts'];
    if (conflicts is! List || conflicts.isEmpty) return null;
    final first = conflicts.first;
    if (first is! Map) return null;
    final clientName = first['client_name'];
    final time = first['time'];
    if (clientName is! String || time is! String) return null;
    return ConsultationScheduleConflictError(
      clientName: clientName,
      time: time,
    );
  }
}

/// Provides the inbox source for the current mode.
final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return DemoConsultationRepository(
      scheduleRepository: () => ref.read(scheduleRepositoryProvider),
    );
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

/// 인박스 한 쪽의 건수. 서버 기본값과 같다(#980).
const int consultationPageSize = 50;

/// 인박스 화면 상태 — 목록과 "더 있는가".
class ConsultationInboxState {
  /// Creates the inbox state.
  const ConsultationInboxState({
    this.requests = const AsyncValue<List<ConsultationRequest>>.loading(),
    this.loadingMore = false,
    this.hasMore = false,
  });

  /// 첫 쪽 + 이어 받은 과거 요청. 화면은 이 값만 그린다.
  final AsyncValue<List<ConsultationRequest>> requests;

  /// 다음 쪽을 받는 중인가 — 버튼이 두 번 눌리는 것을 막는다.
  final bool loadingMore;

  /// 더 받을 것이 남았는가. 마지막 쪽이 상한만큼 왔으면 남았다고 본다.
  final bool hasMore;

  /// Copies with the given fields replaced.
  ConsultationInboxState copyWith({
    AsyncValue<List<ConsultationRequest>>? requests,
    bool? loadingMore,
    bool? hasMore,
  }) => ConsultationInboxState(
    requests: requests ?? this.requests,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
  );
}

/// 인박스 목록 — 폴링하는 첫 쪽 위에 이어 받은 과거 요청을 붙여 둔다. (#980)
///
/// 두 갈래를 나눠 두는 이유: 폴링은 **새로 들어온 요청**을 보려는 것이라 첫 쪽만
/// 다시 읽으면 되고, 이어 받은 과거 요청은 이미 처리된 이력이라 바뀌지 않는다.
/// 매번 전체를 다시 읽으면 인박스가 길어질수록 폴링이 그만큼 무거워진다.
class ConsultationInboxController
    extends StateNotifier<ConsultationInboxState> {
  /// Subscribes to the first page for [status].
  ConsultationInboxController(this._repository, this._status)
    : super(const ConsultationInboxState()) {
    _subscription = _repository
        .watch(status: _status, limit: consultationPageSize)
        .listen(_onFirstPage, onError: _onError);
  }

  final ConsultationRepository _repository;
  final String _status;
  late final StreamSubscription<List<ConsultationRequest>> _subscription;

  /// 이어 받아 둔 과거 요청(오래된 쪽).
  List<ConsultationRequest> _older = const <ConsultationRequest>[];

  void _onFirstPage(List<ConsultationRequest> page) {
    if (!mounted) return;
    // 첫 쪽에 다시 나타난 요청은 이어 받아 둔 목록에서 뺀다 — 같은 요청이 두 줄로
    // 그려지면 트레이너는 요청이 두 건 온 것으로 읽는다.
    final Set<String> ids = page.map((r) => r.id).toSet();
    _older = _older
        .where((ConsultationRequest r) => !ids.contains(r.id))
        .toList(growable: false);
    state = state.copyWith(
      requests: AsyncValue<List<ConsultationRequest>>.data(
        <ConsultationRequest>[...page, ..._older],
      ),
      // 이어 받은 쪽이 있으면 "더 있는가" 는 그 마지막 쪽이 이미 답했다.
      hasMore: _older.isEmpty ? page.length >= consultationPageSize : null,
    );
  }

  void _onError(Object error, StackTrace stack) {
    if (!mounted) return;
    // 이미 받아 둔 목록이 있으면 지우지 않는다 — 폴링 한 번 실패했다고 인박스를
    // 오류 화면으로 덮을 일은 아니다.
    if (state.requests.hasValue) return;
    state = state.copyWith(
      requests: AsyncValue<List<ConsultationRequest>>.error(error, stack),
    );
  }

  /// 과거 요청을 한 쪽 더 이어 붙인다.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final List<ConsultationRequest> shown =
        state.requests.valueOrNull ?? const <ConsultationRequest>[];
    final ConsultationRequest? last = shown.isEmpty ? null : shown.last;
    // 커서를 만들 수 없으면 이어 받지 않는다 — 커서 없이 다시 부르면 첫 쪽이 또 온다.
    if (last?.createdAt == null) {
      state = state.copyWith(hasMore: false);
      return;
    }

    state = state.copyWith(loadingMore: true);
    try {
      final List<ConsultationRequest> page = await _repository.fetch(
        status: _status,
        limit: consultationPageSize,
        before: last!.createdAt,
        beforeId: last.id,
      );
      if (!mounted) return;
      final Set<String> seen = shown.map((r) => r.id).toSet();
      final List<ConsultationRequest> fresh = page
          .where((ConsultationRequest r) => seen.add(r.id))
          .toList(growable: false);
      _older = <ConsultationRequest>[..._older, ...fresh];
      state = state.copyWith(
        requests: AsyncValue<List<ConsultationRequest>>.data(
          <ConsultationRequest>[...shown, ...fresh],
        ),
        loadingMore: false,
        hasMore: page.length >= consultationPageSize,
      );
    } on Object {
      // 이어 받기 실패는 보고 있는 목록을 건드리지 않는다. 다시 누르면 또 시도한다.
      if (!mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// The inbox list for the active filter.
final consultationsProvider =
    StateNotifierProvider.autoDispose<
      ConsultationInboxController,
      ConsultationInboxState
    >((ref) {
      final status = ref.watch(consultationFilterProvider);
      return ConsultationInboxController(
        ref.watch(consultationRepositoryProvider),
        status,
      );
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
Future<ConsultationAcceptResult> acceptConsultation(
  WidgetRef ref,
  String id, {
  ConsultationSchedule? schedule,
}) async {
  final result = await ref
      .read(consultationRepositoryProvider)
      .accept(id, schedule: schedule);
  _refreshAfterDecision(ref);
  ref.invalidate(clientsProvider);
  if (result.scheduleCreated) {
    ref.invalidate(todayScheduleProvider);
    ref.invalidate(scheduleForDateProvider);
    ref.invalidate(bookedDatesProvider);
    ref.invalidate(scheduleRangeProvider);
    ref.invalidate(clientSessionsProvider);
  }
  return result;
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
