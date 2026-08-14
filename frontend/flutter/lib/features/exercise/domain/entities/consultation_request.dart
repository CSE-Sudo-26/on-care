import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';

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
    required this.healthPurposeType,
    required this.healthPurposeDetail,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.message,
    required this.status,
    required this.createdAt,
    this.decisionNote,
    this.decidedAt,
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
    healthPurposeType: healthPurposeType,
    healthPurposeDetail: healthPurposeDetail,
    preferredDate: preferredDate,
    preferredTimeSlot: preferredTimeSlot,
    message: message,
    status: status,
    createdAt: createdAt,
    decisionNote: decisionNote,
    decidedAt: decidedAt,
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

  /// 표시용 라벨이 아니라 **계약 enum** 을 들고 있다. 서버는 코드를 주므로, 라벨을
  /// 저장하면 `GET /consultations/me` 로 복원할 때 문구를 만들 수 없다(#327).
  /// 화면이 이 값으로 현지화 문구를 고른다.
  final ExerciseGoal exerciseGoal;
  final HealthPurposeType healthPurposeType;

  /// `healthPurposeType` 이 other 일 때 사용자가 적은 내용.
  final String? healthPurposeDetail;
  final DateTime preferredDate;
  final PreferredTimeSlot preferredTimeSlot;
  final String? message;
  final ConsultationStatus status;
  final DateTime createdAt;

  /// 트레이너가 거절하며 남긴 사유. 승인이거나 사유를 적지 않았으면 null. (#473)
  ///
  /// "거절됨"만 보여 주면 사용자는 다시 신청해도 되는지, 다른 트레이너를 찾아야
  /// 하는지 판단할 근거가 없다. 서버가 알림 본문으로도 같은 문장을 보낸다.
  final String? decisionNote;

  /// 승인·거절된 시각. 대기 중이면 null.
  final DateTime? decidedAt;

  /// 아직 답을 기다리는 중인가.
  bool get isPending => status == ConsultationStatus.pending;
}

/// `GET /consultations/me` 응답 → 엔티티. (#327)
ConsultationRequest consultationFromJson(Map<String, Object?> j) {
  final bool isTrainer = j['target_type'] == 'trainer';
  return ConsultationRequest(
    id: j['id']! as String,
    targetType: isTrainer
        ? ConsultationTargetType.trainer
        : ConsultationTargetType.gym,
    gymId: (j['gym_id'] as String?) ?? '',
    // 대상이 지워지면 서버가 이름을 못 준다 — 빈 문자열로 두고 화면이 처리한다.
    gymName: (j['gym_name'] as String?) ?? '',
    trainerId: j['trainer_id'] as String?,
    trainerName: j['trainer_name'] as String?,
    // 서버는 트레이너 직함을 상담 응답에 담지 않는다. 목록 카드는 이름만 쓴다.
    trainerRole: null,
    exerciseGoal: exerciseGoalFromWire(j['exercise_goal'] as String?),
    healthPurposeType: healthPurposeFromWire(
      j['health_purpose_type'] as String?,
    ),
    healthPurposeDetail: j['health_purpose_detail'] as String?,
    preferredDate:
        DateTime.tryParse((j['preferred_date'] as String?) ?? '') ??
        DateTime.now(),
    preferredTimeSlot: preferredTimeSlotFromWire(
      j['preferred_time_slot'] as String?,
    ),
    message: j['message'] as String?,
    status: switch (j['status']) {
      'accepted' => ConsultationStatus.accepted,
      'rejected' => ConsultationStatus.rejected,
      _ => ConsultationStatus.pending,
    },
    createdAt:
        DateTime.tryParse((j['created_at'] as String?) ?? '') ?? DateTime.now(),
    // 공백만 남은 사유는 null 로 접는다 — 빈 안내 줄이 그려지지 않도록.
    decisionNote: switch (j['decision_note']) {
      final String note when note.trim().isNotEmpty => note.trim(),
      _ => null,
    },
    decidedAt: DateTime.tryParse((j['decided_at'] as String?) ?? ''),
  );
}
