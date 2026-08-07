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

  /// 서버가 접수하며 준 id 로 갈아끼울 때 쓴다 — 화면이 만든 임시 id 는 트레이너
  /// 앱과 이어지지 않는다(#327).
  ConsultationRequest copyWith({String? id}) => ConsultationRequest(
    id: id ?? this.id,
    targetType: targetType,
    gymId: gymId,
    gymName: gymName,
    trainerId: trainerId,
    trainerName: trainerName,
    trainerRole: trainerRole,
    exerciseGoal: exerciseGoal,
    healthPurpose: healthPurpose,
    preferredDate: preferredDate,
    preferredTimeSlot: preferredTimeSlot,
    message: message,
    status: status,
    createdAt: createdAt,
  );

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
