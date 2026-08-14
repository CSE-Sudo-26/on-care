import 'package:oncare_trainer/features/coaching/data/dtos/program_draft_dtos.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';

/// A saved program draft, as listed in the program tab.
///
/// The list deliberately carries no exercises — it answers "what did I save",
/// and the editor reads the detail when the trainer opens one.
class TrainerProgramDraftSummary {
  const TrainerProgramDraftSummary({
    required this.id,
    required this.name,
    required this.goal,
    required this.period,
    required this.exerciseCount,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String goal;
  final String period;
  final int exerciseCount;
  final DateTime updatedAt;

  factory TrainerProgramDraftSummary.fromJson(Map<String, Object?> json) =>
      TrainerProgramDraftSummary(
        id: json['id']! as String,
        name: json['name'] as String? ?? '',
        goal: json['goal'] as String? ?? '',
        period: json['period'] as String? ?? '',
        exerciseCount: (json['exercise_count'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.parse(json['updated_at']! as String),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'goal': goal,
    'period': period,
    'exercise_count': exerciseCount,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// A saved program draft with its full exercise list.
///
/// **One session only.** Saving multi-session programs is a follow-up to
/// #708, so the server contract carries a single session and the editor
/// keeps its multi-session drafts local until then.
class TrainerProgramDraft {
  const TrainerProgramDraft({
    required this.id,
    required this.name,
    required this.goal,
    required this.period,
    required this.memo,
    required this.sessionName,
    required this.exercises,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String goal;
  final String period;
  final String memo;
  final String sessionName;
  final List<ProgramExerciseDraft> exercises;
  final DateTime updatedAt;

  factory TrainerProgramDraft.fromJson(Map<String, Object?> json) =>
      TrainerProgramDraft(
        id: json['id']! as String,
        name: json['name'] as String? ?? '',
        goal: json['goal'] as String? ?? '',
        period: json['period'] as String? ?? '',
        memo: json['memo'] as String? ?? '',
        sessionName: json['session_name'] as String? ?? '',
        exercises:
            ((json['exercises'] as List<Object?>?) ?? const <Object?>[])
                .map(
                  (item) => programExerciseFromJson(
                    (item! as Map<Object?, Object?>).cast<String, Object?>(),
                  ),
                )
                .toList(),
        updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? json['created_at']! as String,
        ),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'goal': goal,
    'period': period,
    'memo': memo,
    'session_name': sessionName,
    'exercises': exercises.map(programExerciseToJson).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Rebuilds the editor state so a reopened draft renders exactly as it was
  /// saved — including which items came from the AI (`source`).
  ProgramEditorState toEditorState({required String fallbackSessionName}) =>
      ProgramEditorState(
        name: name,
        goal: goal,
        period: period,
        memo: memo,
        sessions: <ProgramSessionDraft>[
          ProgramSessionDraft(
            id: 'session-1',
            name: sessionName.isEmpty ? fallbackSessionName : sessionName,
            exercises: exercises,
          ),
        ],
      );
}
