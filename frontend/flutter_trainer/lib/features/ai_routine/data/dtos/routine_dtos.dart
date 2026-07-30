import 'package:oncare_trainer/features/ai_routine/domain/entities/assigned_routine.dart';

/// Valid routine types accepted by the backend (`RoutineType` literal).
const List<String> kRoutineTypes = <String>['유산소', '근력', '스트레칭'];

/// `RoutineOut` JSON → [AssignedRoutine].
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
Map<String, Object?> assignRoutineToJson(AssignedRoutine r) {
  return <String, Object?>{
    'name': r.name.trim().isEmpty
        ? 'AI 맞춤 루틴'
        : _truncate(r.name.trim(), 100),
    'minutes': r.minutes.clamp(0, 600),
    'type': kRoutineTypes.contains(r.type) ? r.type : '근력',
    'reason': _truncate(r.reason, 200),
    'source': r.source == 'trainer' ? 'trainer' : 'ai',
  };
}

String _str(Object? v) => v is String ? v : '';

String _truncate(String s, int max) =>
    s.length <= max ? s : s.substring(0, max);
