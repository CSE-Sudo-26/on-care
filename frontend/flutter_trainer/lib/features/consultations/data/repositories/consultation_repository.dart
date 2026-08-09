import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
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

  /// Number of undecided requests — the sidebar badge.
  Future<int> pendingCount();

  /// Accepts [id], creating the trainer↔member link server-side.
  Future<void> accept(String id);

  /// Rejects [id]. [note] is delivered to the member as the reason.
  Future<void> reject(String id, {String? note});
}

/// Demo build: no inbox. Reads succeed with nothing so any consumer that
/// does run (tests, a deep link) renders an empty state instead of an
/// error, and decisions are refused rather than silently doing nothing.
class DemoConsultationRepository implements ConsultationRepository {
  /// Creates the demo source.
  const DemoConsultationRepository();

  @override
  bool get supportsInbox => false;

  @override
  Future<List<ConsultationRequest>> fetch({String status = 'pending'}) async =>
      const <ConsultationRequest>[];

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<void> accept(String id) async =>
      throw const ValidationError();

  @override
  Future<void> reject(String id, {String? note}) async =>
      throw const ValidationError();
}

/// Real backend: `/trainer/consultations`.
class DioConsultationRepository implements ConsultationRepository {
  /// Creates the API-backed repository.
  const DioConsultationRepository(this._dio);

  final Dio _dio;

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
  Future<void> accept(String id) => _decide(id, 'accept', null);

  @override
  Future<void> reject(String id, {String? note}) =>
      _decide(id, 'reject', note);

  /// Both decisions share their failure modes, so they share the mapping.
  ///
  /// 409 carries the server's own reason — already decided, or the member
  /// already has another trainer. That sentence is exactly what the
  /// trainer needs, so it is surfaced instead of a generic network error.
  Future<void> _decide(String id, String action, String? note) async {
    try {
      await _dio.post<Map<String, Object?>>(
        '/trainer/consultations/${Uri.encodeComponent(id)}/$action',
        data: <String, Object?>{'note': note},
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
    return const DemoConsultationRepository();
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
final consultationsProvider = FutureProvider<List<ConsultationRequest>>((
  ref,
) async {
  final status = ref.watch(consultationFilterProvider);
  return ref.watch(consultationRepositoryProvider).fetch(status: status);
}, name: 'consultations');

/// Pending count for the sidebar badge.
///
/// Its own request rather than `consultationsProvider.length`: the badge
/// must stay correct while the trainer is looking at the `all` filter, and
/// it is read from the sidebar on every page.
final consultationPendingCountProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(consultationInboxEnabledProvider)) return 0;
  return ref.watch(consultationRepositoryProvider).pendingCount();
}, name: 'consultationPendingCount');

/// Accepts a request and refreshes everything it changed.
///
/// The roster is invalidated too — accepting is precisely the moment a new
/// client appears, and a stale 고객 tab would make the trainer wonder
/// whether the approval worked.
Future<void> acceptConsultation(WidgetRef ref, String id) async {
  await ref.read(consultationRepositoryProvider).accept(id);
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
