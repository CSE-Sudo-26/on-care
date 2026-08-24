/// One exercise inside a [ProgramTemplate].
class TemplateExercise {
  /// Creates a template exercise.
  const TemplateExercise({
    required this.name,
    required this.minutes,
    required this.type,
    this.sets = 0,
    this.reps = '',
  });

  /// Exercise name.
  final String name;

  /// Duration in minutes.
  final int minutes;

  /// 서버 `RoutineType` 계약값(걷기·유산소·근력·요가·스트레칭·기타). 화면
  /// 문구는 `routineTypeLabel` 이 붙인다 — 번역하면 서버가 422 를 돌려준다.
  final String type;

  /// 근력 운동에서만 쓴다(#1029) — `ProgramItem`/`ProgramExerciseDraft` 와
  /// 같은 계약(`sets: int`, `reps: String`). 비근력 운동은 기본값(0/빈
  /// 문자열)으로 두고 [minutes] 만 쓴다.
  final int sets;
  final String reps;

  /// `ProgramTemplateExercise` 한 줄.
  factory TemplateExercise.fromJson(Map<String, Object?> json) =>
      TemplateExercise(
        name: json['name'] as String? ?? '',
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? '근력',
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        reps: json['reps'] as String? ?? '',
      );

  /// 저장 요청에 실리는 형태.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'minutes': minutes,
    'type': type,
    'sets': sets,
    'reps': reps,
  };
}

/// A reusable block of exercises the trainer can drop into a routine.
///
/// The AI proposes from the client's data; templates carry the
/// trainer's own repeated patterns ("혈압 관리 기본", "하체 근력 A"). Both
/// end up in the same composed routine — applying a template appends to
/// the AI's suggestions rather than replacing them.
class ProgramTemplate {
  /// Creates a template.
  const ProgramTemplate({
    required this.id,
    required this.name,
    required this.goal,
    required this.exercises,
  });

  /// Stable id.
  final String id;

  /// Display name.
  final String name;

  /// Who it's for (e.g. 혈압 관리 · 초급).
  final String goal;

  /// The block's exercises.
  final List<TemplateExercise> exercises;

  /// 저장된 내 템플릿이 아니라 **서버가 주는 시작 구성**인가. (#920)
  ///
  /// 저장해 둔 템플릿이 하나도 없을 때만 내려온다. 고치거나 지울 대상이 아니라
  /// 화면이 그 두 동작을 내밀지 않는다 — 대신 편집하면 내 첫 템플릿으로 새로
  /// 저장된다.
  bool get isStarter => id.startsWith('starter:');

  /// Total duration.
  int get totalMinutes => exercises.fold<int>(0, (sum, e) => sum + e.minutes);

  /// `TrainerProgramTemplateOut` 한 건.
  factory ProgramTemplate.fromJson(Map<String, Object?> json) =>
      ProgramTemplate(
        id: json['id']! as String,
        name: json['name'] as String? ?? '',
        goal: json['goal'] as String? ?? '',
        exercises: <TemplateExercise>[
          for (final item in (json['exercises'] as List<dynamic>? ?? const []))
            if (item is Map<String, Object?>) TemplateExercise.fromJson(item),
        ],
      );
}
