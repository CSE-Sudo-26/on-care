/// The generated A/B routine options for a member — the `RoutineOptionsOut`
/// shape from `POST /trainer/clients/{id}/routine-options`. Generated, not
/// assigned: the trainer picks/edits one, then sends it via the routine
/// assign API.
library;

/// The member-state summary the generation was grounded on (step 1).
class MemberAnalysis {
  const MemberAnalysis({
    required this.goal,
    required this.sodiumTodayMg,
    required this.sodiumOverTarget,
    required this.avgCompletionRate,
    required this.latestRoutine,
    required this.note,
  });

  final String goal;
  final int sodiumTodayMg;
  final bool sodiumOverTarget;
  final int avgCompletionRate;
  final String latestRoutine;
  final String note;
}

/// One exercise line in a plan.
class RoutineExercise {
  const RoutineExercise({
    required this.name,
    required this.minutes,
    required this.type,
  });

  final String name;
  final int minutes;
  final String type;

  RoutineExercise copyWith({String? name, int? minutes, String? type}) =>
      RoutineExercise(
        name: name ?? this.name,
        minutes: minutes ?? this.minutes,
        type: type ?? this.type,
      );
}

/// One generated plan (A recovery/sustainable or B intensity/volume).
class RoutinePlan {
  const RoutinePlan({
    required this.key,
    required this.label,
    required this.totalMinutes,
    required this.intensity,
    required this.exercises,
    required this.reason,
    required this.rationale,
  });

  /// "A" or "B".
  final String key;
  final String label;
  final int totalMinutes;
  final String intensity;
  final List<RoutineExercise> exercises;
  final String reason;

  /// Data-grounded rationale citing the member's numbers.
  final String rationale;
}

/// The full A/B options response.
class RoutineOptions {
  const RoutineOptions({
    required this.analysis,
    required this.planA,
    required this.planB,
    required this.generatedBy,
  });

  final MemberAnalysis analysis;
  final RoutinePlan planA;
  final RoutinePlan planB;

  /// "ai" (LLM) or "rule" (deterministic fallback).
  final String generatedBy;
}
