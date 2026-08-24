import 'package:oncare_trainer/features/coaching/domain/exercise_estimate.dart';

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
  /// program of any number of sessions (#709). 숫자 칸은 스테퍼가 이미 범위
  /// 안으로 묶어 두므로(#1276) 여기서 볼 것은 이름뿐이다.
  bool get supportsAssignment {
    final exercises = <ProgramExerciseDraft>[
      for (final session in sessions) ...session.exercises,
    ];
    if (exercises.isEmpty) return false;
    return exercises.every((ProgramExerciseDraft e) {
      final int length = e.name.trim().length;
      return length >= 1 && length <= 100;
    });
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

/// 편집기의 운동 한 항목.
///
/// 회원 앱의 운동 추가 시트와 같은 칸을 받는다(#1276) — 날짜·종류·이름·
/// 시간(또는 세트·중량)·강도. 예전에는 세트·횟수·중량·시간·거리·휴식·RPE 가
/// 전부 자유 문자열이라 같은 운동이 화면마다 다른 모양으로 저장됐고, 회원
/// 기록과 나란히 집계할 수가 없었다. 통일 스펙에 없는 횟수·거리·휴식·RPE 는
/// 뺐다 — 강도가 RPE 자리를 대신한다.
class ProgramExerciseDraft {
  const ProgramExerciseDraft({
    required this.id,
    required this.name,
    this.type = '근력',
    this.date,
    this.minutes = 30,
    this.sets = 3,
    this.weight = 20,
    this.intensity = 'moderate',
    this.memo = '',
    this.source = 'trainer',
    this.templateName,
  });

  final String id;
  final String name;
  final String type;

  /// 이 운동을 하는 날. 아직 정하지 않았으면 null.
  final DateTime? date;

  /// 유산소·스트레칭·기타의 운동 시간(분). 근력은 세트로 재므로 쓰지 않는다.
  final int minutes;

  /// 근력의 세트 수와 중량(kg). 시간과 따로 들고 있어야 유형을 오갈 때 각자의
  /// 값이 남는다 — 하나로 쓰면 30분이 30세트가 되어 돌아온다.
  final int sets;
  final double weight;

  /// 운동 강도 계약값('light'|'moderate'|'high').
  final String intensity;

  final String memo;

  /// 지금 고른 유형이 근력인가.
  bool get isStrength => type == '근력';

  /// 저장·칼로리 계산이 쓰는 분. 근력이면 세트에서 환산한 값이다 — 서버는
  /// 여전히 분을 요구하고 주간 운동 시간도 분으로 센다.
  int get effectiveMinutes => isStrength ? minutesFromSets(sets) : minutes;

  /// 예상 소모 칼로리 — 세 유형을 한 축에서 견주는 값이다.
  int get calories => estimateRoutineCalories(
    type: type,
    minutes: effectiveMinutes,
    intensity: intensity,
  );

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
    String? type,
    DateTime? date,
    int? minutes,
    int? sets,
    double? weight,
    String? intensity,
    String? memo,
    String? source,
    String? templateName,
  }) => ProgramExerciseDraft(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    date: date ?? this.date,
    minutes: minutes ?? this.minutes,
    sets: sets ?? this.sets,
    weight: weight ?? this.weight,
    intensity: intensity ?? this.intensity,
    memo: memo ?? this.memo,
    source: source ?? this.source,
    templateName: templateName ?? this.templateName,
  );
}
