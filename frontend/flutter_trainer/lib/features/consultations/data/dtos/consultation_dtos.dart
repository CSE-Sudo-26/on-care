import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Maps the `TrainerConsultationOut` JSON into [ConsultationRequest].
///
/// Kept out of the Dio repository so the mapping is unit-testable on its
/// own — the enum→한국어 tables below are the part most likely to drift
/// from the backend's `Literal` types.

/// 운동 목표 코드 → 화면 문구. The backend stores the code so the label can
/// change without a migration; the mapping has to live on one side and the
/// trainer console is the only place it is read.
Map<String, String> exerciseGoalLabels(AppLocalizations l) => <String, String>{
  'weight_loss': l.goalWeightLoss,
  'strength': l.goalStrength,
  'fitness': l.goalFitness,
  'posture': l.goalPosture,
  'health': l.goalHealth,
  'other': l.goalOther,
};

/// 건강관리 목적 코드 → 화면 문구.
Map<String, String> healthPurposeLabels(AppLocalizations l) => <String, String>{
  'weight': l.purposeWeight,
  'chronic': l.purposeChronic,
  'rehab': l.purposeRehab,
  'general': l.purposeGeneral,
  'none': l.purposeNone,
  'other': l.purposeOther,
};

/// 희망 시간대 코드 → 화면 문구.
Map<String, String> preferredTimeLabels(AppLocalizations l) => <String, String>{
  'morning': l.slotMorning,
  'afternoon': l.slotAfternoon,
  'evening': l.slotEvening,
  'flexible': l.slotFlexible,
};

/// `GET /v1/trainer/consultations` element → [ConsultationRequest].
///
/// Unknown enum codes fall back to the raw code rather than an empty
/// string: a backend that adds `sports_rehab` should show something the
/// trainer can act on, not a blank line.
ConsultationRequest consultationRequestFromJson(Map<String, Object?> json) {
  return ConsultationRequest(
    id: _str(json['id']),
    memberId: _str(json['member_id']),
    memberName: _nullable(json['member_name']) ?? '',
    goalCode: _str(json['exercise_goal']),
    purposeCode: _str(json['health_purpose_type']),
    purposeDetail: _nullable(json['health_purpose_detail']),
    preferredDate: _date(json['preferred_date']),
    preferredTimeCode: _str(json['preferred_time_slot']),
    message: _nullable(json['message']),
    status: _str(json['status']),
    decisionNote: _nullable(json['decision_note']),
  );
}

String _str(Object? value) => value is String ? value : '';

/// Trims and collapses empty strings to null — the API sends `null` for an
/// omitted note, but a whitespace-only note would otherwise render an
/// empty bubble.
String? _nullable(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// 코드 → 라벨. 모르는 코드는 원문 그대로 — 백엔드가 새 값을 추가해도
/// 빈 줄이 아니라 트레이너가 읽을 무언가가 남는다.
String label(Map<String, String> table, Object? code) {
  final raw = _str(code);
  return table[raw] ?? (raw.isEmpty ? '-' : raw);
}

/// `YYYY-MM-DD` → [DateTime]. An unparseable value yields the epoch rather
/// than throwing: one malformed row must not blank the whole inbox.
DateTime _date(Object? value) =>
    DateTime.tryParse(_str(value)) ?? DateTime.fromMillisecondsSinceEpoch(0);
