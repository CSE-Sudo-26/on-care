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

Map<String, String> healthPurposeLabels(AppLocalizations l) => <String, String>{
  'weight': l.goalWeightLoss,
  'chronic': l.memberHealthConditions,
  'rehab': l.goalPosture,
  'general': l.goalHealth,
  'none': '-',
  'other': l.goalOther,
};

/// 희망 시각 코드 → 화면 문구. `flexible` 이거나 `HH:MM` 정확한 시각이다(#1256).
///
/// 예전 morning/afternoon/evening 값이 이미 접수된 요청에 남아 있을 수 있어, 그
/// 값을 포함해 패턴에 맞지 않는 코드는 전부 "시간 협의"로 떨어뜨린다 — 원문
/// 코드를 그대로 보여주면 트레이너 화면에 `morning` 이 노출된다.
final RegExp _kPreferredTimePattern = RegExp(
  r'^([01]\d|2[0-3]):([0-5]\d)(?:-([01]\d|2[0-3]):([0-5]\d))?$',
);

/// The fixed start time encoded in [code] as `HH:mm`, or `null` for
/// `flexible` or a legacy morning/afternoon/evening bucket — those carry no
/// exact time to seed a session with. A range (`HH:mm-HH:mm`) yields its
/// start.
String? preferredStartTime(String code) {
  final RegExpMatch? match = _kPreferredTimePattern.firstMatch(code);
  if (match == null) return null;
  return '${match.group(1)}:${match.group(2)}';
}

String preferredTimeLabel(AppLocalizations l, String code) {
  final RegExpMatch? match = _kPreferredTimePattern.firstMatch(code);
  if (match == null) return l.slotFlexible;
  String label(String hourText, String minute) {
    final int hour = int.parse(hourText);
    final String period = hour < 12 ? l.slotAm : l.slotPm;
    final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$period $hour12:$minute';
  }

  final String start = label(match.group(1)!, match.group(2)!);
  if (match.group(3) == null) return start;
  return '$start–${label(match.group(3)!, match.group(4)!)}';
}

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
    createdAt: DateTime.tryParse(_str(json['created_at'])),
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
