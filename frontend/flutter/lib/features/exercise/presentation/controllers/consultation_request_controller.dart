import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/exercise/data/repositories/dio_consultation_repository.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/repositories/consultation_repository.dart';

/// 데모는 서버로 나가지 않는다 — `LocalApiInterceptor` 에 `/consultations` 핸들러가
/// 없다. 실 API 모드에서만 접수가 백엔드로 간다(#327).
final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return const MockConsultationRepository();
  }
  return DioConsultationRepository(ref.watch(dioProvider));
}, name: 'consultationRepository');

class ConsultationRequestController
    extends StateNotifier<List<ConsultationRequest>> {
  ConsultationRequestController(this._repository)
    : super(const <ConsultationRequest>[]);

  final ConsultationRepository _repository;

  /// [trainerId] narrows trainer-target lookups to one person — a gym has
  /// several trainers, so a request to one must not block the others.
  bool hasPending({
    required ConsultationTargetType targetType,
    required String gymId,
    String? trainerId,
  }) {
    return state.any(
      (ConsultationRequest request) =>
          request.targetType == targetType &&
          request.gymId == gymId &&
          (targetType != ConsultationTargetType.trainer ||
              request.trainerId == trainerId) &&
          request.status == ConsultationStatus.pending,
    );
  }

  /// 서버에 접수하고 목록에 넣는다. 접수되면 서버가 준 id 를 쓴 요청을 돌려주고,
  /// 이미 대기 중이면 null 을 돌려준다.
  ///
  /// 예전에는 메모리에만 쌓아 새로고침하면 사라지고 트레이너 앱에도 전달되지
  /// 않았다(#327 no-op).
  Future<ConsultationRequest?> submit({
    required ConsultationDraft draft,
    required ConsultationRequest display,
  }) async {
    if (hasPending(
      targetType: display.targetType,
      gymId: display.gymId,
      trainerId: display.trainerId,
    )) {
      return null;
    }

    final String id;
    try {
      id = await _repository.create(draft);
    } on DuplicatePendingConsultation {
      // 다른 기기에서 이미 신청했을 수 있다 — 서버 판정을 따른다.
      return null;
    }

    // 서버 id 가 있을 때만 갈아끼운다. 빈 값(데모)에서 copyWith 를 부르면 값이 같아도
    // 새 인스턴스가 되어, 넣은 객체와 같은지 보는 쪽이 어긋난다.
    final ConsultationRequest saved = id.isEmpty
        ? display
        : display.copyWith(id: id);
    state = <ConsultationRequest>[saved, ...state];
    return saved;
  }
}

final consultationRequestControllerProvider =
    StateNotifierProvider<
      ConsultationRequestController,
      List<ConsultationRequest>
    >(
      (ref) =>
          ConsultationRequestController(ref.watch(consultationRepositoryProvider)),
      name: 'consultationRequests',
    );
