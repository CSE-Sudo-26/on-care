import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';

/// Maps the `TrainerConsultationOut` JSON into [ConsultationRequest].
///
/// Kept out of the Dio repository so the mapping is unit-testable on its
/// own — the enum→한국어 tables below are the part most likely to drift
/// from the backend's `Literal` types.

/// 운동 목표 코드 → 화면 문구. The backend stores the code so the label can
/// change without a migration; the mapping has to live on one side and the
/// trainer console is the only place it is read.
const Map<String, String> kExerciseGoalLabels = <String, String>{
  'weight_loss': '체중 감량',
  'strength': '근력 향상',
  'fitness': '체력 증진',
  'posture': '자세 교정',
  'health': '건강 관리',
  'other': '기타',
};

/// 건강관리 목적 코드 → 화면 문구.
const Map<String, String> kHealthPurposeLabels = <String, String>{
  'weight': '체중 관리',
  'chronic': '만성질환 관리',
  'rehab': '재활',
  'general': '전반적 건강',
  'none': '해당 없음',
  'other': '기타',
};

/// 희망 시간대 코드 → 화면 문구.
const Map<String, String> kPreferredTimeLabels = <String, String>{
  'morning': '오전',
  'afternoon': '오후',
  'evening': '저녁',
  'flexible': '조율 가능',
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
    memberName: _nullable(json['member_name']) ?? '알 수 없는 회원',
    goalLabel: _label(kExerciseGoalLabels, json['exercise_goal']),
    purposeLabel: _label(kHealthPurposeLabels, json['health_purpose_type']),
    purposeDetail: _nullable(json['health_purpose_detail']),
    preferredDate: _date(json['preferred_date']),
    preferredTimeLabel: _label(kPreferredTimeLabels, json['preferred_time_slot']),
    message: _nullable(json['message']),
    status: _str(json['status']),
    viaGym: json['via_gym'] == true,
    gymName: _nullable(json['gym_name']),
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

String _label(Map<String, String> table, Object? code) {
  final raw = _str(code);
  return table[raw] ?? (raw.isEmpty ? '-' : raw);
}

/// `YYYY-MM-DD` → [DateTime]. An unparseable value yields the epoch rather
/// than throwing: one malformed row must not blank the whole inbox.
DateTime _date(Object? value) =>
    DateTime.tryParse(_str(value)) ?? DateTime.fromMillisecondsSinceEpoch(0);
