/// Frontend-only draft for the Figma multi-session program editor.
///
/// This deliberately does not implement or extend [AssignedRoutine]: the
/// current backend routine contract is flat and cannot safely persist these
/// fields. A future Program DTO should map to this state explicitly.
class ProgramEditorState {
  const ProgramEditorState({
    required this.name,
    this.goal = '',
    this.period = '',
    this.memo = '',
    required this.sessions,
  });

  final String name;
  final String goal;
  final String period;
  final String memo;
  final List<ProgramSessionDraft> sessions;

  /// Whether this draft can be represented by the current flat routine API.
  bool get supportsFlatRoutine {
    if (sessions.length != 1 || sessions.single.exercises.isEmpty) {
      return false;
    }
    for (final exercise in sessions.single.exercises) {
      final nameLength = exercise.name.trim().length;
      final sets = int.tryParse(exercise.sets.trim());
      if (nameLength < 1 || nameLength > 100 || sets == null) return false;
      if (sets < 0 || sets > 99) return false;
    }
    return true;
  }

  ProgramEditorState copyWith({
    String? name,
    String? goal,
    String? period,
    String? memo,
    List<ProgramSessionDraft>? sessions,
  }) => ProgramEditorState(
    name: name ?? this.name,
    goal: goal ?? this.goal,
    period: period ?? this.period,
    memo: memo ?? this.memo,
    sessions: sessions ?? this.sessions,
  );

  factory ProgramEditorState.initial({
    required String clientGoal,
    required String programName,
    required String sessionName,
  }) => ProgramEditorState(
    name: programName,
    goal: clientGoal,
    sessions: <ProgramSessionDraft>[
      ProgramSessionDraft(
        id: 'session-1',
        name: sessionName,
        exercises: const [],
      ),
    ],
  );
}

class ProgramSessionDraft {
  const ProgramSessionDraft({
    required this.id,
    required this.name,
    required this.exercises,
  });

  final String id;
  final String name;
  final List<ProgramExerciseDraft> exercises;

  ProgramSessionDraft copyWith({
    String? name,
    List<ProgramExerciseDraft>? exercises,
  }) => ProgramSessionDraft(
    id: id,
    name: name ?? this.name,
    exercises: exercises ?? this.exercises,
  );
}

class ProgramExerciseDraft {
  const ProgramExerciseDraft({
    required this.id,
    required this.name,
    this.sets = '3',
    this.reps = '10',
    this.weight = '',
    this.duration = '',
    this.distance = '',
    this.rest = '60',
    this.rpe = '',
    this.memo = '',
    this.type = '근력',
    this.source = 'trainer',
  });

  final String id;
  final String name;
  final String sets;
  final String reps;
  final String weight;
  final String duration;
  final String distance;
  final String rest;
  final String rpe;
  final String memo;
  final String type;
  final String source;

  ProgramExerciseDraft copyWith({
    String? name,
    String? sets,
    String? reps,
    String? weight,
    String? duration,
    String? distance,
    String? rest,
    String? rpe,
    String? memo,
    String? type,
    String? source,
  }) => ProgramExerciseDraft(
    id: id,
    name: name ?? this.name,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    weight: weight ?? this.weight,
    duration: duration ?? this.duration,
    distance: distance ?? this.distance,
    rest: rest ?? this.rest,
    rpe: rpe ?? this.rpe,
    memo: memo ?? this.memo,
    type: type ?? this.type,
    source: source ?? this.source,
  );
}
