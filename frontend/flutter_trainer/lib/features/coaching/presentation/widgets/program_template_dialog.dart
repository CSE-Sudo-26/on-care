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
    final starter = widget.template?.isStarter ?? false;

    return AlertDialog(
      title: Text(
        widget.template == null || starter
            ? l.coachTemplateNew
            : l.coachTemplateEdit,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (starter) ...<Widget>[
                Text(
                  l.coachTemplateStarterHint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
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
          child: Text(
            starter ? l.coachTemplateSaveAsMine : l.coachTemplateSave,
          ),
        ),
      ],
    );
  }
}

/// 편집 중인 운동 한 줄. 컨트롤러를 들고 있어 다이얼로그가 닫힐 때 정리한다.
class _ExerciseDraft {
  _ExerciseDraft({
    required this.name,
    required this.minutes,
    required this.type,
  }) : key = _nextKey++;

  factory _ExerciseDraft.empty() => _ExerciseDraft(
    name: TextEditingController(),
    minutes: TextEditingController(text: '10'),
    type: kRoutineTypes.first,
  );

  factory _ExerciseDraft.from(TemplateExercise exercise) => _ExerciseDraft(
    name: TextEditingController(text: exercise.name),
    minutes: TextEditingController(text: '${exercise.minutes}'),
    type: kRoutineTypes.contains(exercise.type)
        ? exercise.type
        : kRoutineTypes.first,
  );

  static int _nextKey = 0;

  final int key;
  final TextEditingController name;
  final TextEditingController minutes;
  String type;

  /// 이름이 비었거나 시간이 0 이하면 저장 대상이 아니다 — 빈 줄을 남긴 채
  /// 저장을 눌러도 그 줄만 조용히 빠진다.
  TemplateExercise? toExercise() {
    final label = name.text.trim();
    final duration = int.tryParse(minutes.text.trim()) ?? 0;
    if (label.isEmpty || duration <= 0) return null;
    return TemplateExercise(name: label, minutes: duration, type: type);
  }

  void dispose() {
    name.dispose();
    minutes.dispose();
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
                  decoration: InputDecoration(
                    labelText: l.coachTemplateExerciseName,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: draft.minutes,
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
