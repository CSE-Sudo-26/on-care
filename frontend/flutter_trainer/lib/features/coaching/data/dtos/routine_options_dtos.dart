import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';

/// `RoutineOptionsOut` JSON → [RoutineOptions]. Kept separate from the Dio
/// repository so the DTO ↔ domain mapping is unit-testable.
RoutineOptions routineOptionsFromJson(Map<String, Object?> json) {
  final options = RoutineOptions(
    analysis: _analysis(json['analysis']),
    planA: _plan(json['plan_a']),
    planB: _plan(json['plan_b']),
    generatedBy: _requiredString(json, 'generated_by'),
  );
  if (options.planA.key != 'A' || options.planB.key != 'B') {
    throw const FormatException('routine-options must contain A and B plans.');
  }
  if (options.generatedBy != 'ai' && options.generatedBy != 'rule') {
    throw const FormatException('Invalid routine-options generator.');
  }
  return options;
}

MemberAnalysis _analysis(Object? v) {
  final m = _requiredMap(v, 'analysis');
  return MemberAnalysis(
    goal: _requiredString(m, 'goal'),
    sodiumTodayMg: _requiredInt(m, 'sodium_today_mg'),
    sodiumOverTarget: _requiredBool(m, 'sodium_over_target'),
    avgCompletionRate: _requiredInt(m, 'avg_completion_rate'),
    latestRoutine: _requiredString(m, 'latest_routine'),
    note: _requiredString(m, 'note'),
  );
}

RoutinePlan _plan(Object? v) {
  final m = _requiredMap(v, 'plan');
  final ex = m['exercises'];
  if (ex is! List) {
    throw const FormatException('Invalid routine plan exercises.');
  }
  return RoutinePlan(
    key: _requiredString(m, 'key'),
    label: _requiredString(m, 'label'),
    totalMinutes: _requiredInt(m, 'total_minutes'),
    intensity: _requiredString(m, 'intensity'),
    exercises: ex
        .map((item) {
          final exercise = _requiredMap(item, 'exercise');
          return RoutineExercise(
            name: _requiredString(exercise, 'name'),
            minutes: _requiredInt(exercise, 'minutes'),
            type: _requiredString(exercise, 'type'),
          );
        })
        .toList(growable: false),
    reason: _requiredString(m, 'reason'),
    rationale: _requiredString(m, 'rationale'),
  );
}

Map<String, Object?> _requiredMap(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('Invalid routine-options $field.');
}

String _requiredString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is String) return value;
  throw FormatException('Invalid routine-options $field.');
}

int _requiredInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is num) return value.toInt();
  throw FormatException('Invalid routine-options $field.');
}

bool _requiredBool(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw FormatException('Invalid routine-options $field.');
}
