import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';

class ConsultationRequestController
    extends StateNotifier<List<ConsultationRequest>> {
  ConsultationRequestController() : super(const <ConsultationRequest>[]);

  bool hasPending({
    required ConsultationTargetType targetType,
    required String gymId,
  }) {
    return state.any(
      (ConsultationRequest request) =>
          request.targetType == targetType &&
          request.gymId == gymId &&
          request.status == ConsultationStatus.pending,
    );
  }

  bool add(ConsultationRequest request) {
    if (hasPending(targetType: request.targetType, gymId: request.gymId)) {
      return false;
    }
    state = <ConsultationRequest>[request, ...state];
    return true;
  }
}

final consultationRequestControllerProvider =
    StateNotifierProvider<
      ConsultationRequestController,
      List<ConsultationRequest>
    >((ref) => ConsultationRequestController(), name: 'consultationRequests');
