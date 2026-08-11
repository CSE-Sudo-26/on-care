import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Valid routine types accepted by the backend (`RoutineType` literal).
///
/// **번역하지 않는다.** 이 값은 화면 문구가 아니라 서버로 나가는 계약값이다 —
/// 영어 로케일에서 `type: 'Strength'` 를 보내면 백엔드 Literal 검증에 걸려 422 가
/// 난다. 화면에 보일 문구는 [routineTypeLabel] 로 따로 가져온다. (#501)
const List<String> kRoutineTypes = <String>[
  '걷기',
  '유산소',
  '근력',
  '요가',
  '스트레칭',
  '기타',
];

/// `RoutineOut` JSON → [AssignedRoutine].
/// 저장된 계약값 → 화면 문구.
String routineTypeLabel(AppLocalizations l, String type) => switch (type) {
  '걷기' => l.routineTypeWalking,
  '유산소' => l.routineTypeCardio,
  '근력' => l.routineTypeStrength,
  '요가' => l.routineTypeYoga,
  '스트레칭' => l.routineTypeStretching,
  '기타' => l.routineTypeOther,
  // 서버가 새 유형을 추가했는데 앱이 모르는 경우 — 원문을 그대로 보여 준다.
  _ => type,
};

AssignedRoutine assignedRoutineFromJson(Map<String, Object?> json) {
  return AssignedRoutine(
    id: _str(json['id']),
    name: _str(json['name']),
    minutes: json['minutes'] is num ? (json['minutes']! as num).toInt() : 0,
    type: _str(json['type']),
    reason: _str(json['reason']),
    source: _str(json['source']),
  );
}

/// [AssignedRoutine] → `RoutineAssignRequest` JSON. Clamps/normalises so the
/// backend's validators (minutes 0–600, type literal, lengths) never 422.
///
/// [clientRequestId] 는 전송 시도의 멱등키다. 넣어 보내면 같은 키의 재요청이
/// 새 배정을 만들지 않는다(#581). 생략하면 서버는 기존처럼 매번 새로 배정한다.
Map<String, Object?> assignRoutineToJson(
  AssignedRoutine r, {
  String? clientRequestId,
}) {
  return <String, Object?>{
    'name': r.name.trim().isEmpty ? 'AI 맞춤 루틴' : _truncate(r.name.trim(), 100),
    'minutes': r.minutes.clamp(0, 600),
    'type': kRoutineTypes.contains(r.type) ? r.type : '근력',
    'reason': _truncate(r.reason, 200),
    'source': r.source == 'trainer' ? 'trainer' : 'ai',
    'client_request_id': ?clientRequestId,
  };
}

String _str(Object? v) => v is String ? v : '';

String _truncate(String s, int max) =>
    s.length <= max ? s : s.substring(0, max);

/// Picks the dominant exercise type and the routine `source` for a
/// composed send (AI-suggested items still on screen + trainer-added
/// custom exercises). Pure so the "all-custom falls back to 근력/ai" class
/// of bug is directly unit-testable (review), matching the [assignRoutine]
/// summary the trainer sees before sending.
///
///  * `type` — the most frequent type across both lists (ties keep the
///    first-seen type via a strict `>` comparison), defaulting to '근력'
///    when there are no exercises at all.
///  * `source` — `'trainer'` when every AI suggestion was removed (an
///    all-custom routine is trainer-authored, not AI-generated), `'ai'`
///    otherwise.
({String type, String source}) summaryTypeAndSource({
  required List<String> aiItemTypes,
  required List<String> customItemTypes,
}) {
  final counts = <String, int>{};
  for (final t in <String>[...aiItemTypes, ...customItemTypes]) {
    counts[t] = (counts[t] ?? 0) + 1;
  }
  var type = '근력';
  var best = 0;
  counts.forEach((t, c) {
    if (c > best) {
      best = c;
      type = t;
    }
  });
  return (type: type, source: aiItemTypes.isEmpty ? 'trainer' : 'ai');
}
