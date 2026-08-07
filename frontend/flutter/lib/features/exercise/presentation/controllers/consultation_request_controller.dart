import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';

class ConsultationRequestController
    extends StateNotifier<List<ConsultationRequest>> {
  ConsultationRequestController() : super(const <ConsultationRequest>[]);

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

  bool add(ConsultationRequest request) {
    if (hasPending(
      targetType: request.targetType,
      gymId: request.gymId,
      trainerId: request.trainerId,
    )) {
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
