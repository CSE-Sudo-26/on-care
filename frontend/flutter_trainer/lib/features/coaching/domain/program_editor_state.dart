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

  /// Whether this draft can be assigned to a member or put on the schedule.
  ///
  /// Session count is no longer part of the answer — the backend takes a
  /// program of any number of sessions (#709). What still matters is that
  /// every exercise carries values the assignment contract accepts: a name,
  /// and a set count the schedule's `ProgramItem` can hold.
  bool get supportsAssignment {
    final exercises = <ProgramExerciseDraft>[
      for (final session in sessions) ...session.exercises,
    ];
    if (exercises.isEmpty) return false;
    for (final exercise in exercises) {
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
    this.templateName,
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

  /// `ai` | `trainer` — 서버가 받는 계약값이다(`kProgramExerciseSources`).
  /// 화면 표시는 [templateName] 이 있으면 그쪽을 우선한다.
  final String source;

  /// 이 운동을 끌어온 템플릿 이름(#1029) — 있으면 출처 배지가 `트레이너
  /// 추가` 대신 `$templateName 템플릿 추가` 를 보여 준다. 화면 전용 값이라
  /// [source] 는 그대로 `trainer` 로 남고, 배정 payload
  /// (`programExerciseToJson`) 는 이 필드를 읽지 않는다 — 서버 계약을 넓히지
  /// 않는다.
  final String? templateName;

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
    String? templateName,
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
    templateName: templateName ?? this.templateName,
  );
}
