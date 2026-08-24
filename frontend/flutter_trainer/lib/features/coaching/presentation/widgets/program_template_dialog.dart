import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_program_template_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 템플릿을 만들고 고치는 다이얼로그. (#920)
///
/// [template] 이 없으면 새로 만들고, 있으면 그 값으로 열린다. **시작 구성을
/// 열었을 때도 저장은 '새로 만들기'** 다 — 시작 구성은 저장된 행이 아니라
/// 고칠 대상이 없고, 손을 대는 순간 그 트레이너의 첫 템플릿이 된다.
///
/// 운동 줄은 이름·시간·종류 셋뿐이다. 세트·중량까지 담지 않는 이유는 템플릿이
/// 프로그램이 아니라 **블록**이기 때문이다 — 회원마다 달라지는 값은 적용한 뒤
/// 편집기에서 정한다.
class ProgramTemplateDialog extends ConsumerStatefulWidget {
  const ProgramTemplateDialog({super.key, this.template});

  /// 고칠 템플릿. 시작 구성이면 저장 시 새 템플릿이 만들어진다.
  final ProgramTemplate? template;

  @override
  ConsumerState<ProgramTemplateDialog> createState() =>
      _ProgramTemplateDialogState();
}

class _ProgramTemplateDialogState extends ConsumerState<ProgramTemplateDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.template?.name ?? '',
  );
  late final TextEditingController _goal = TextEditingController(
    text: widget.template?.goal ?? '',
  );
  late final List<_ExerciseDraft> _exercises = <_ExerciseDraft>[
    for (final exercise
        in widget.template?.exercises ?? const <TemplateExercise>[])
      _ExerciseDraft.from(exercise),
    if ((widget.template?.exercises ?? const <TemplateExercise>[]).isEmpty)
      _ExerciseDraft.empty(),
  ];

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    for (final draft in _exercises) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.coachTemplateNameRequired);
      return;
    }
    final exercises = <TemplateExercise>[
      for (final draft in _exercises)
        if (draft.toExercise() case final TemplateExercise exercise) exercise,
    ];
    if (exercises.isEmpty) {
      setState(() => _error = l.coachTemplateExerciseRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(trainerProgramTemplateRepositoryProvider);
      final existing = widget.template;
      // 시작 구성은 고칠 행이 없다 — 손을 댄 순간 내 첫 템플릿으로 저장된다.
      if (existing == null || existing.isStarter) {
        await repository.create(
          name: name,
          goal: _goal.text.trim(),
          exercises: exercises,
        );
      } else {
        await repository.update(
          existing.id,
          name: name,
          goal: _goal.text.trim(),
          exercises: exercises,
        );
      }
      ref.invalidate(programTemplatesProvider);
      if (!mounted) return;
      navigator.pop();
    } on AppError catch (error) {
      if (!mounted) return;
      setState(
        () => _error = serverDetailOr(
          l,
          error.message,
          l.coachTemplateSaveFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    // 시작 구성이든 직접 만든 템플릿이든 편집 창은 똑같이 생겼다 — 저장 시
    // 시작 구성만 조용히 새 템플릿으로 만들어지는 차이는 데이터 계층
    // (`_save`)에만 있고, 화면엔 드러내지 않는다.
    return AlertDialog(
      title: Text(widget.template == null ? l.coachTemplateNew : l.coachTemplateEdit),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('template-name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: l.coachTemplateNameLabel,
                  errorText: _error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('template-goal'),
                controller: _goal,
                decoration: InputDecoration(
                  labelText: l.coachTemplateGoalLabel,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var index = 0; index < _exercises.length; index++)
                _ExerciseRow(
                  key: ValueKey<int>(_exercises[index].key),
                  draft: _exercises[index],
                  onChanged: () => setState(() {}),
                  onRemove: _exercises.length == 1
                      ? null
                      : () => setState(() {
                          _exercises.removeAt(index).dispose();
                        }),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _exercises.add(_ExerciseDraft.empty())),
                  icon: const Icon(Icons.add),
                  label: Text(l.coachTemplateAddExercise),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('template-save'),
          onPressed: _saving ? null : _save,
          child: Text(l.coachTemplateSave),
        ),
      ],
    );
  }
}

/// 편집 중인 운동 한 줄. 컨트롤러를 들고 있어 다이얼로그가 닫힐 때 정리한다.
///
/// `sets`/`reps` 는 근력일 때만 쓴다(#1029) — 그 외 유형은 [minutes] 만
/// 쓴다. 유형을 근력으로 바꾼 뒤 시간 칸은 화면에서 숨지만 값은 그대로
/// 남아 있다(기본 10분) — 백엔드 계약(`ProgramTemplateExercise.minutes`)이
/// 여전히 1 이상을 요구하기 때문이다.
class _ExerciseDraft {
  _ExerciseDraft({
    required this.name,
    required this.minutes,
    required this.sets,
    required this.weight,
    required this.type,
  }) : key = _nextKey++;

  factory _ExerciseDraft.empty() => _ExerciseDraft(
    name: TextEditingController(),
    minutes: TextEditingController(text: '10'),
    sets: TextEditingController(text: '3'),
    weight: TextEditingController(text: '20'),
    type: kRoutineTypes.first,
  );

  factory _ExerciseDraft.from(TemplateExercise exercise) => _ExerciseDraft(
    name: TextEditingController(text: exercise.name),
    minutes: TextEditingController(text: '${exercise.minutes}'),
    sets: TextEditingController(
      text: exercise.sets > 0 ? '${exercise.sets}' : '3',
    ),
    weight: TextEditingController(
      text: exercise.weight > 0 ? '${exercise.weight}' : '20',
    ),
    type: kRoutineTypes.contains(exercise.type)
        ? exercise.type
        : kRoutineTypes.first,
  );

  static int _nextKey = 0;

  final int key;
  final TextEditingController name;
  final TextEditingController minutes;
  final TextEditingController sets;
  final TextEditingController weight;
  String type;

  /// 이름이 비었거나 시간이 0 이하면 저장 대상이 아니다 — 빈 줄을 남긴 채
  /// 저장을 눌러도 그 줄만 조용히 빠진다.
  TemplateExercise? toExercise() {
    final label = name.text.trim();
    final duration = int.tryParse(minutes.text.trim()) ?? 0;
    if (label.isEmpty || duration <= 0) return null;
    final isStrength = type == '근력';
    return TemplateExercise(
      name: label,
      minutes: duration,
      type: type,
      // 비근력은 저장하지 않는다 — 화면에서 숨긴 값이 조용히 실리면
      // 안 쓰는 필드가 남아 있는 것처럼 보인다.
      sets: isStrength ? (int.tryParse(sets.text.trim()) ?? 0) : 0,
      weight: isStrength ? (double.tryParse(weight.text.trim()) ?? 0) : 0,
    );
  }

  void dispose() {
    name.dispose();
    minutes.dispose();
    sets.dispose();
    weight.dispose();
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.draft,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  final _ExerciseDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  /// 트레이너웹의 다른 운동 입력칸([_DraftField] 류)과 맞춘 타이포다.
  static const TextStyle _fieldStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.foreground,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final isStrength = draft.type == '근력';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TextField(
                  controller: draft.name,
                  style: _fieldStyle,
                  decoration: InputDecoration(
                    labelText: l.coachTemplateExerciseName,
                    hintText: l.aiExerciseNameExample,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 근력은 세트·횟수로, 그 외 유형은 시간으로 잰다(#1029).
              if (isStrength) ...<Widget>[
                Expanded(
                  child: TextField(
                    controller: draft.sets,
                    style: _fieldStyle,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: l.programEditorSets,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: draft.weight,
                    style: _fieldStyle,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l.programEditorWeight,
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: TextField(
                    controller: draft.minutes,
                    style: _fieldStyle,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: l.coachTemplateExerciseMinutes,
                    ),
                  ),
                ),
              IconButton(
                tooltip: l.a11yRemoveExercise,
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          RoutineCategoryChips(
            value: draft.type,
            onChanged: (value) {
              draft.type = value;
              onChanged();
            },
            keyPrefix: 'template-category-${draft.key}',
          ),
        ],
      ),
    );
  }
}
