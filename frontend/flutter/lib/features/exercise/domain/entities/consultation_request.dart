enum ConsultationTargetType { gym, trainer }

enum ConsultationStatus { pending, accepted, rejected }

class ConsultationRequest {
  const ConsultationRequest({
    required this.id,
    required this.targetType,
    required this.gymId,
    required this.gymName,
    required this.trainerId,
    required this.trainerName,
    required this.trainerRole,
    required this.exerciseGoal,
    required this.healthPurpose,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final ConsultationTargetType targetType;
  final String gymId;
  final String gymName;

  /// Set for trainer-target requests. A gym has several trainers, so pending
  /// state must be matched on this rather than on [gymId].
  final String? trainerId;
  final String? trainerName;
  final String? trainerRole;
  final String exerciseGoal;
  final String healthPurpose;
  final DateTime preferredDate;
  final String preferredTimeSlot;
  final String? message;
  final ConsultationStatus status;
  final DateTime createdAt;
}
