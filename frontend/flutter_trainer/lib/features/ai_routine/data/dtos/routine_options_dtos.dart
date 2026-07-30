import 'package:oncare_trainer/features/ai_routine/domain/entities/routine_options.dart';

/// `RoutineOptionsOut` JSON → [RoutineOptions]. Kept separate from the Dio
/// repository so the DTO ↔ domain mapping is unit-testable.
RoutineOptions routineOptionsFromJson(Map<String, Object?> json) {
  return RoutineOptions(
    analysis: _analysis(json['analysis']),
    planA: _plan(json['plan_a']),
    planB: _plan(json['plan_b']),
    generatedBy: _str(json['generated_by']),
  );
}

MemberAnalysis _analysis(Object? v) {
  final m = v is Map<String, Object?> ? v : const <String, Object?>{};
  return MemberAnalysis(
    goal: _str(m['goal']),
    sodiumTodayMg: _int(m['sodium_today_mg']),
    sodiumOverTarget: m['sodium_over_target'] == true,
    avgCompletionRate: _int(m['avg_completion_rate']),
    latestRoutine: _str(m['latest_routine']),
    note: _str(m['note']),
  );
}

RoutinePlan _plan(Object? v) {
  final m = v is Map<String, Object?> ? v : const <String, Object?>{};
  final ex = m['exercises'];
  return RoutinePlan(
    key: _str(m['key']),
    label: _str(m['label']),
    totalMinutes: _int(m['total_minutes']),
    intensity: _str(m['intensity']),
    exercises: ex is List
        ? ex
            .whereType<Map<String, Object?>>()
            .map(
              (e) => RoutineExercise(
                name: _str(e['name']),
                minutes: _int(e['minutes']),
                type: _str(e['type']),
              ),
            )
            .toList(growable: false)
        : const <RoutineExercise>[],
    reason: _str(m['reason']),
    rationale: _str(m['rationale']),
  );
}

String _str(Object? v) => v is String ? v : '';

int _int(Object? v) => v is num ? v.toInt() : 0;
