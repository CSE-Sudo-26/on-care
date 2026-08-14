import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';

/// Wire values the backend accepts for an exercise's origin.
const List<String> kProgramExerciseSources = <String>['ai', 'trainer'];

/// Longest value the backend stores per free-text exercise field
/// (`ProgramDraftExercise` uses `max_length=30`). Trimming here means an
/// over-long paste is saved shortened rather than 422-ing the whole draft.
const int _kFieldMax = 30;
const int _kMemoMax = 300;
const int _kNameMax = 100;

String _cap(String value, int max) {
  final trimmed = value.trim();
  return trimmed.length <= max ? trimmed : trimmed.substring(0, max);
}

/// [ProgramExerciseDraft] → `ProgramDraftExercise` JSON.
///
/// Clamps to the server's validators so a draft never fails to save over a
/// value the editor happily accepted — losing the trainer's work to a 422 is
/// worse than storing a shortened note.
Map<String, Object?> programExerciseToJson(ProgramExerciseDraft exercise) =>
    <String, Object?>{
      'id': _cap(exercise.id, 64),
      // The backend requires a name; a blank row would reject the draft.
      'name': exercise.name.trim().isEmpty
          ? '-'
          : _cap(exercise.name, _kNameMax),
      'sets': _cap(exercise.sets, _kFieldMax),
      'reps': _cap(exercise.reps, _kFieldMax),
      'weight': _cap(exercise.weight, _kFieldMax),
      'duration': _cap(exercise.duration, _kFieldMax),
      'distance': _cap(exercise.distance, _kFieldMax),
      'rest': _cap(exercise.rest, _kFieldMax),
      'rpe': _cap(exercise.rpe, _kFieldMax),
      'memo': _cap(exercise.memo, _kMemoMax),
      'type': kRoutineTypes.contains(exercise.type) ? exercise.type : '근력',
      'source': kProgramExerciseSources.contains(exercise.source)
          ? exercise.source
          : 'trainer',
    };

/// `ProgramDraftExercise` JSON → [ProgramExerciseDraft].
ProgramExerciseDraft programExerciseFromJson(Map<String, Object?> json) =>
    ProgramExerciseDraft(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sets: json['sets'] as String? ?? '',
      reps: json['reps'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      rest: json['rest'] as String? ?? '',
      rpe: json['rpe'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      type: json['type'] as String? ?? '근력',
      source: json['source'] as String? ?? 'trainer',
    );

/// [ProgramEditorState] → create/update payload.
///
/// Only the first session goes to the server — multi-session saving is a
/// follow-up to #708, and the editor blocks the save button for drafts that
/// have more than one.
Map<String, Object?> programDraftToJson(ProgramEditorState draft) {
  final session = draft.sessions.isEmpty ? null : draft.sessions.first;
  return <String, Object?>{
    'name': _cap(draft.name, _kNameMax),
    'goal': _cap(draft.goal, 200),
    'period': _cap(draft.period, _kNameMax),
    'memo': _cap(draft.memo, 2000),
    'session_name': _cap(session?.name ?? '', _kNameMax),
    'exercises': <Map<String, Object?>>[
      for (final exercise in session?.exercises ?? const <ProgramExerciseDraft>[])
        programExerciseToJson(exercise),
    ],
  };
}
