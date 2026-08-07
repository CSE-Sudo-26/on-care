/// `POST /consultations` 로 보내는 값. (#327)
///
/// 화면이 들고 있던 선택지는 현지화된 **라벨**이라 서버 계약(enum 코드)과 맞지 않았다.
/// 여기 enum 이 계약이고, 라벨은 화면이 이 enum 으로부터 만든다.
library;

enum ExerciseGoal { weightLoss, strength, fitness, posture, health, other }

enum HealthPurposeType { weight, chronic, rehab, general, none, other }

enum PreferredTimeSlot { morning, afternoon, evening, flexible }

/// 백엔드 `ConsultationCreate` 의 Literal 값과 문자 그대로 같아야 한다.
String exerciseGoalToWire(ExerciseGoal g) => switch (g) {
  ExerciseGoal.weightLoss => 'weight_loss',
  ExerciseGoal.strength => 'strength',
  ExerciseGoal.fitness => 'fitness',
  ExerciseGoal.posture => 'posture',
  ExerciseGoal.health => 'health',
  ExerciseGoal.other => 'other',
};

String healthPurposeToWire(HealthPurposeType p) => switch (p) {
  HealthPurposeType.weight => 'weight',
  HealthPurposeType.chronic => 'chronic',
  HealthPurposeType.rehab => 'rehab',
  HealthPurposeType.general => 'general',
  HealthPurposeType.none => 'none',
  HealthPurposeType.other => 'other',
};

String preferredTimeSlotToWire(PreferredTimeSlot t) => switch (t) {
  PreferredTimeSlot.morning => 'morning',
  PreferredTimeSlot.afternoon => 'afternoon',
  PreferredTimeSlot.evening => 'evening',
  PreferredTimeSlot.flexible => 'flexible',
};

/// 상담 신청 내용. 대상은 헬스장 **또는** 트레이너 하나다 — 서버가 둘 다 오거나
/// 둘 다 비면 422 로 거절한다.
class ConsultationDraft {
  const ConsultationDraft({
    required this.gymId,
    required this.trainerId,
    required this.exerciseGoal,
    required this.healthPurposeType,
    required this.healthPurposeDetail,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.message,
  });

  /// 헬스장 상담이면 값, 트레이너 상담이면 null.
  final String? gymId;

  /// 트레이너 상담이면 값, 헬스장 상담이면 null.
  final String? trainerId;
  final ExerciseGoal exerciseGoal;
  final HealthPurposeType healthPurposeType;

  /// `healthPurposeType` 이 other 면 필수 — 서버가 422 로 강제한다.
  final String? healthPurposeDetail;
  final DateTime preferredDate;
  final PreferredTimeSlot preferredTimeSlot;
  final String? message;

  Map<String, Object?> toJson() {
    // 서버는 대상이 정확히 하나여야 하고, other 목적에는 상세가 있어야 한다(422).
    // 여기서 막지 않으면 둘 다 실린 payload 가 그대로 나가 원인을 찾기 어려운
    // 422 로 돌아온다.
    if ((gymId == null) == (trainerId == null)) {
      throw ArgumentError(
        '상담 대상은 헬스장·트레이너 중 정확히 하나여야 합니다 '
        '(gymId=$gymId, trainerId=$trainerId).',
      );
    }
    if (healthPurposeType == HealthPurposeType.other &&
        (healthPurposeDetail == null || healthPurposeDetail!.trim().isEmpty)) {
      throw ArgumentError('기타 건강관리 목적에는 상세 내용이 필요합니다.');
    }
    return _json();
  }

  Map<String, Object?> _json() => <String, Object?>{
    'target_type': trainerId != null ? 'trainer' : 'gym',
    'gym_id': gymId,
    'trainer_id': trainerId,
    'exercise_goal': exerciseGoalToWire(exerciseGoal),
    'health_purpose_type': healthPurposeToWire(healthPurposeType),
    'health_purpose_detail': healthPurposeDetail,
    // 날짜만 보낸다(YYYY-MM-DD) — 서버 계약이 date 다.
    'preferred_date':
        '${preferredDate.year.toString().padLeft(4, '0')}-'
        '${preferredDate.month.toString().padLeft(2, '0')}-'
        '${preferredDate.day.toString().padLeft(2, '0')}',
    'preferred_time_slot': preferredTimeSlotToWire(preferredTimeSlot),
    'message': message,
  };
}
