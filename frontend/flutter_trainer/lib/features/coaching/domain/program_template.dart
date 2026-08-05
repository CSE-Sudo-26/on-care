/// One exercise inside a [ProgramTemplate].
class TemplateExercise {
  /// Creates a template exercise.
  const TemplateExercise({
    required this.name,
    required this.minutes,
    required this.type,
  });

  /// Exercise name.
  final String name;

  /// Duration in minutes.
  final int minutes;

  /// 유산소 | 근력 | 스트레칭.
  final String type;
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

  /// Total duration.
  int get totalMinutes => exercises.fold<int>(0, (sum, e) => sum + e.minutes);
}

/// The built-in template library.
///
/// Bundled rather than stored: templates are trainer-authored content,
/// and there is no endpoint to persist them yet. Keeping them as data
/// (not hardcoded widgets) means the CRUD screen, when it lands, only
/// has to swap this list for a repository.
const List<ProgramTemplate> programTemplates = <ProgramTemplate>[
  ProgramTemplate(
    id: 'tpl-bp-basic',
    name: '혈압 관리 기본',
    goal: '혈압 관리 · 초급',
    exercises: <TemplateExercise>[
      TemplateExercise(name: '준비 스트레칭', minutes: 10, type: '스트레칭'),
      TemplateExercise(name: '저강도 걷기', minutes: 20, type: '유산소'),
      TemplateExercise(name: '호흡 이완', minutes: 10, type: '스트레칭'),
    ],
  ),
  ProgramTemplate(
    id: 'tpl-fatloss',
    name: '체중 감량 순환',
    goal: '체중 감량 · 중급',
    exercises: <TemplateExercise>[
      TemplateExercise(name: '인터벌 유산소', minutes: 20, type: '유산소'),
      TemplateExercise(name: '전신 서킷', minutes: 20, type: '근력'),
      TemplateExercise(name: '마무리 스트레칭', minutes: 10, type: '스트레칭'),
    ],
  ),
  ProgramTemplate(
    id: 'tpl-lower-a',
    name: '하체 근력 A',
    goal: '근력 향상 · 중급',
    exercises: <TemplateExercise>[
      TemplateExercise(name: '레그프레스', minutes: 15, type: '근력'),
      TemplateExercise(name: '루마니안 데드리프트', minutes: 15, type: '근력'),
      TemplateExercise(name: '카프 레이즈', minutes: 10, type: '근력'),
    ],
  ),
];
