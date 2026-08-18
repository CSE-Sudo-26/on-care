import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/core/utils/clock.dart';

/// Rich local draft editor matching the Figma program workspace.
///
/// Multi-session persistence remains unsupported. A one-session draft can be
/// handed to the existing flat routine boundary through the supplied actions.
class ProgramEditorWorkspace extends StatefulWidget {
  const ProgramEditorWorkspace({
    super.key,
    required this.clientGoal,
    required this.aiSuggestions,
    required this.onAssignFlat,
    required this.onRegisterFlat,
    required this.registerOffset,
    required this.onRegisterOffsetChanged,
    this.template,
    this.templateRevision = 0,
    this.assigning = false,
    this.registering = false,
    this.initialDraft,
    this.onSave,
    this.saving = false,
    this.editingSaved = false,
  });

  final String clientGoal;
  final List<AiRoutineItem> aiSuggestions;
  final ProgramTemplate? template;
  final int templateRevision;
  final Future<void> Function(ProgramEditorState draft) onAssignFlat;
  final Future<void> Function(ProgramEditorState draft) onRegisterFlat;
  final int registerOffset;
  final ValueChanged<int> onRegisterOffsetChanged;
  final bool assigning;
  final bool registering;

  /// A saved draft to open instead of starting from the client's goal.
  ///
  /// AI suggestions are **not** appended on top of it — the saved draft is
  /// what the trainer decided on, and re-adding proposals they already
  /// accepted or dropped would quietly change their work (#708).
  final ProgramEditorState? initialDraft;

  /// Saves the current draft. Null when saving isn't wired up.
  final Future<void> Function(ProgramEditorState draft)? onSave;

  /// A save is in flight — the button locks so a second click can't create
  /// a duplicate draft.
  final bool saving;

  /// Whether the editor is working on an already-saved draft (overwrite)
  /// rather than a new one.
  final bool editingSaved;

  @override
  State<ProgramEditorWorkspace> createState() => _ProgramEditorWorkspaceState();
}

class _ProgramEditorWorkspaceState extends State<ProgramEditorWorkspace> {
  late ProgramEditorState _draft;
  var _initialized = false;
  var _editingProgramInfo = false;
  String? _addingToSession;
  final TextEditingController _exerciseName = TextEditingController();
  String _newExerciseType = '근력';
  var _nextId = 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final l = AppLocalizations.of(context);
    final saved = widget.initialDraft;
    if (saved != null) {
      _draft = saved;
      _nextId = saved.sessions.fold<int>(
            0,
            (count, session) => count + session.exercises.length,
          ) +
          2;
    } else {
      _draft = ProgramEditorState.initial(
        clientGoal: widget.clientGoal,
        programName: l.programEditorDefaultName(widget.clientGoal),
        sessionName: l.programEditorDefaultSession,
      );
      _appendAiSuggestions(widget.aiSuggestions);
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _exerciseName.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProgramEditorWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) return;
    // A reopened draft is not topped up with proposals — see [initialDraft].
    if (widget.initialDraft == null &&
        widget.aiSuggestions != oldWidget.aiSuggestions) {
      _appendAiSuggestions(widget.aiSuggestions);
    }
    if (widget.templateRevision == oldWidget.templateRevision) {
      return;
    }
    final template = widget.template;
    if (template == null) return;
    final first = _draft.sessions.first;
    final additions = <ProgramExerciseDraft>[
      for (final exercise in template.exercises)
        ProgramExerciseDraft(
          id: 'exercise-${_nextId++}',
          name: exercise.name,
          duration: '${exercise.minutes}',
          type: exercise.type,
        ),
    ];
    _replaceSession(
      0,
      first.copyWith(
        exercises: <ProgramExerciseDraft>[...first.exercises, ...additions],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // 세션 수는 더 이상 막는 이유가 아니다 — 서버가 세션 여러 개짜리 프로그램을
    // 저장·배정·등록한다(#709). 남은 조건은 값이 계약에 맞는지뿐이다.
    final canAssign = _draft.supportsAssignment;
    final canSave = widget.onSave != null && _draft.name.trim().isNotEmpty;
    return SectionCard(
      title: _draft.name,
      dense: true,
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: <Widget>[
          Tooltip(
            message: canSave ? '' : l.programEditorSaveUnsupported,
            child: ActionButton(
              key: const ValueKey<String>('program-editor-save'),
              label: widget.saving
                  ? l.progSaving
                  : (widget.editingSaved ? l.programEditorSaveEdit : l.actionSave),
              onPressed: canSave && !widget.saving
                  ? () => widget.onSave!(_draft)
                  : null,
            ),
          ),
          Tooltip(
            message: canAssign ? '' : l.programEditorAssignUnsupported,
            child: ActionButton(
              key: const ValueKey<String>('program-editor-assign'),
              label: l.programEditorAssign,
              primary: true,
              onPressed: canAssign && !widget.assigning
                  ? () => widget.onAssignFlat(_draft)
                  : null,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.programEditorInfo,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProgramInfo(
            draft: _draft,
            editing: _editingProgramInfo,
            onEdit: () => setState(() => _editingProgramInfo = true),
            onClose: () => setState(() => _editingProgramInfo = false),
            onChanged: _update,
          ),
          if (widget.aiSuggestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.all(AppRadius.md),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.programEditorAiHint,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ActionButton(
                    label: l.programEditorApply,
                    onPressed: _applyAiSuggestions,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.programEditorExerciseConfig,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ActionButton(
                label: l.programEditorAddSession,
                icon: Icons.add,
                onPressed: _addSession,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (
            var index = 0;
            index < _draft.sessions.length;
            index++
          ) ...<Widget>[
            _SessionEditor(
              key: ValueKey<String>(_draft.sessions[index].id),
              session: _draft.sessions[index],
              canMoveUp: index > 0,
              canMoveDown: index < _draft.sessions.length - 1,
              canDelete: _draft.sessions.length > 1,
              addingExercise: _addingToSession == _draft.sessions[index].id,
              exerciseNameController: _exerciseName,
              exerciseType: _newExerciseType,
              onNameChanged: (value) => _replaceSession(
                index,
                _draft.sessions[index].copyWith(name: value),
              ),
              onMoveUp: () => _moveSession(index, -1),
              onMoveDown: () => _moveSession(index, 1),
              onDelete: () => _deleteSession(index),
              onStartAdd: () => setState(() {
                _addingToSession = _draft.sessions[index].id;
                _exerciseName.clear();
              }),
              onCancelAdd: _cancelExerciseAdd,
              onExerciseTypeChanged: (type) =>
                  setState(() => _newExerciseType = type),
              onConfirmAdd: () => _addExercise(index),
              onExerciseChanged: (exerciseIndex, exercise) =>
                  _replaceExercise(index, exerciseIndex, exercise),
              onMoveExercise: (exerciseIndex, direction) =>
                  _moveExercise(index, exerciseIndex, direction),
              onDeleteExercise: (exerciseIndex) =>
                  _deleteExercise(index, exerciseIndex),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (var offset = 0; offset < 7; offset++) ...<Widget>[
                        ChoiceChip(
                          label: Text(_dayLabel(l, offset)),
                          selected: widget.registerOffset == offset,
                          onSelected: (_) =>
                              widget.onRegisterOffsetChanged(offset),
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.card,
                          side: const BorderSide(color: AppColors.borderStrong),
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: widget.registerOffset == offset
                                ? AppColors.primaryForeground
                                : AppColors.mutedForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ActionButton(
                key: const ValueKey<String>('program-editor-register'),
                label: l.coachRegisterOn(_dayLabel(l, widget.registerOffset)),
                icon: Icons.calendar_today_outlined,
                onPressed: canAssign && !widget.registering
                    ? () => widget.onRegisterFlat(_draft)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _update(ProgramEditorState next) => setState(() => _draft = next);

  void _replaceSession(int index, ProgramSessionDraft session) {
    final sessions = [..._draft.sessions]..[index] = session;
    _update(_draft.copyWith(sessions: sessions));
  }

  void _addSession() {
    final l = AppLocalizations.of(context);
    final id = 'session-${_nextId++}';
    _update(
      _draft.copyWith(
        sessions: <ProgramSessionDraft>[
          ..._draft.sessions,
          ProgramSessionDraft(
            id: id,
            name: l.programEditorSessionName(
              String.fromCharCode(64 + _draft.sessions.length + 1),
            ),
            exercises: const <ProgramExerciseDraft>[],
          ),
        ],
      ),
    );
  }

  void _moveSession(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _draft.sessions.length) return;
    final sessions = [..._draft.sessions];
    final moving = sessions.removeAt(index);
    sessions.insert(target, moving);
    _update(_draft.copyWith(sessions: sessions));
  }

  void _deleteSession(int index) {
    if (_draft.sessions.length == 1) return;
    final sessions = [..._draft.sessions]..removeAt(index);
    _update(_draft.copyWith(sessions: sessions));
  }

  void _addExercise(int sessionIndex) {
    final name = _exerciseName.text.trim();
    if (name.isEmpty) return;
    final session = _draft.sessions[sessionIndex];
    _replaceSession(
      sessionIndex,
      session.copyWith(
        exercises: <ProgramExerciseDraft>[
          ...session.exercises,
          ProgramExerciseDraft(
            id: 'exercise-${_nextId++}',
            name: name,
            type: _newExerciseType,
          ),
        ],
      ),
    );
    _cancelExerciseAdd();
  }

  void _cancelExerciseAdd() {
    setState(() {
      _addingToSession = null;
      _exerciseName.clear();
      _newExerciseType = '근력';
    });
  }

  void _replaceExercise(
    int sessionIndex,
    int exerciseIndex,
    ProgramExerciseDraft exercise,
  ) {
    final session = _draft.sessions[sessionIndex];
    final exercises = [...session.exercises]..[exerciseIndex] = exercise;
    _replaceSession(sessionIndex, session.copyWith(exercises: exercises));
  }

  void _moveExercise(int sessionIndex, int exerciseIndex, int direction) {
    final session = _draft.sessions[sessionIndex];
    final target = exerciseIndex + direction;
    if (target < 0 || target >= session.exercises.length) return;
    final exercises = [...session.exercises];
    final moving = exercises.removeAt(exerciseIndex);
    exercises.insert(target, moving);
    _replaceSession(sessionIndex, session.copyWith(exercises: exercises));
  }

  void _deleteExercise(int sessionIndex, int exerciseIndex) {
    final session = _draft.sessions[sessionIndex];
    final exercises = [...session.exercises]..removeAt(exerciseIndex);
    _replaceSession(sessionIndex, session.copyWith(exercises: exercises));
  }

  void _applyAiSuggestions() => _appendAiSuggestions(widget.aiSuggestions);

  void _appendAiSuggestions(List<AiRoutineItem> suggestions) {
    final first = _draft.sessions.first;
    final existingNames = first.exercises.map((item) => item.name).toSet();
    final additions = <ProgramExerciseDraft>[
      for (final item in suggestions)
        if (existingNames.add(item.name))
          ProgramExerciseDraft(
            id: 'exercise-${_nextId++}',
            name: item.name,
            duration: '${item.minutes}',
            memo: item.reason,
            type: item.type,
            source: 'ai',
          ),
    ];
    if (additions.isEmpty) return;
    final sessions = <ProgramSessionDraft>[
      first.copyWith(
        exercises: <ProgramExerciseDraft>[...first.exercises, ...additions],
      ),
      ..._draft.sessions.skip(1),
    ];
    if (_initialized) {
      _update(_draft.copyWith(sessions: sessions));
      return;
    }
    _draft = _draft.copyWith(sessions: sessions);
  }
}

String _dayLabel(AppLocalizations l, int offset) {
  if (offset == 0) return l.labelToday;
  if (offset == 1) return l.labelTomorrow;
  final date = nowKst().add(Duration(days: offset));
  return '${date.month}/${date.day}';
}

class _ProgramInfo extends StatelessWidget {
  const _ProgramInfo({
    required this.draft,
    required this.editing,
    required this.onEdit,
    required this.onClose,
    required this.onChanged,
  });

  final ProgramEditorState draft;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onClose;
  final ValueChanged<ProgramEditorState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!editing) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.all(AppRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  _InfoChip(label: l.programEditorGoal, value: draft.goal),
                  _InfoChip(label: l.programEditorPeriod, value: draft.period),
                  _InfoChip(label: l.programEditorMemo, value: draft.memo),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey<String>('program-info-edit'),
              tooltip: l.actionEdit,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              color: AppColors.primary,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _DraftField(
                fieldId: 'program-name',
                label: l.programEditorName,
                value: draft.name,
                width: 220,
                onChanged: (value) => onChanged(draft.copyWith(name: value)),
              ),
              _DraftField(
                fieldId: 'program-goal',
                label: l.programEditorGoal,
                value: draft.goal,
                width: 180,
                onChanged: (value) => onChanged(draft.copyWith(goal: value)),
              ),
              _DraftField(
                fieldId: 'program-period',
                label: l.programEditorPeriod,
                value: draft.period,
                width: 150,
                onChanged: (value) => onChanged(draft.copyWith(period: value)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DraftField(
            fieldId: 'program-memo',
            label: l.programEditorMemo,
            value: draft.memo,
            width: double.infinity,
            onChanged: (value) => onChanged(draft.copyWith(memo: value)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: ActionButton(
              label: l.actionClose,
              icon: Icons.check,
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: hasValue ? AppColors.accentSurface : AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        hasValue ? '$label · $value' : '+ $label',
        style: TextStyle(
          color: hasValue ? AppColors.primary : AppColors.mutedForeground,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SessionEditor extends StatefulWidget {
  const _SessionEditor({
    super.key,
    required this.session,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.addingExercise,
    required this.exerciseNameController,
    required this.exerciseType,
    required this.onNameChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onStartAdd,
    required this.onCancelAdd,
    required this.onExerciseTypeChanged,
    required this.onConfirmAdd,
    required this.onExerciseChanged,
    required this.onMoveExercise,
    required this.onDeleteExercise,
  });

  final ProgramSessionDraft session;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final bool addingExercise;
  final TextEditingController exerciseNameController;
  final String exerciseType;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onStartAdd;
  final VoidCallback onCancelAdd;
  final ValueChanged<String> onExerciseTypeChanged;
  final VoidCallback onConfirmAdd;
  final void Function(int, ProgramExerciseDraft) onExerciseChanged;
  final void Function(int, int) onMoveExercise;
  final ValueChanged<int> onDeleteExercise;

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  var _editingName = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.drag_indicator,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: _buildSessionName()),
              if (_editingName)
                IconButton(
                  tooltip: l.actionClose,
                  onPressed: () => setState(() => _editingName = false),
                  icon: const Icon(Icons.check, size: 17),
                  color: AppColors.primary,
                )
              else
                PopupMenuButton<String>(
                  key: ValueKey<String>('session-actions-${widget.session.id}'),
                  tooltip: l.actionEdit,
                  icon: const Icon(Icons.more_horiz, size: 19),
                  onSelected: _handleSessionAction,
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: _MenuLabel(
                        icon: Icons.edit_outlined,
                        label: l.actionEdit,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'up',
                      enabled: widget.canMoveUp,
                      child: _MenuLabel(
                        icon: Icons.keyboard_arrow_up,
                        label: l.programEditorSessionUp,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'down',
                      enabled: widget.canMoveDown,
                      child: _MenuLabel(
                        icon: Icons.keyboard_arrow_down,
                        label: l.programEditorSessionDown,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      enabled: widget.canDelete,
                      child: _MenuLabel(
                        icon: Icons.delete_outline,
                        label: l.actionDelete,
                        destructive: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (widget.session.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                l.programEditorSessionEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subtleForeground,
                  fontSize: 12,
                ),
              ),
            ),
          for (
            var index = 0;
            index < widget.session.exercises.length;
            index++
          ) ...<Widget>[
            _ExerciseEditor(
              key: ValueKey<String>(widget.session.exercises[index].id),
              exercise: widget.session.exercises[index],
              canMoveUp: index > 0,
              canMoveDown: index < widget.session.exercises.length - 1,
              onChanged: (value) => widget.onExerciseChanged(index, value),
              onMoveUp: () => widget.onMoveExercise(index, -1),
              onMoveDown: () => widget.onMoveExercise(index, 1),
              onDelete: () => widget.onDeleteExercise(index),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (widget.addingExercise)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('custom-exercise-name'),
                        controller: widget.exerciseNameController,
                        autofocus: true,
                        onSubmitted: (_) => widget.onConfirmAdd(),
                        decoration: InputDecoration(
                          hintText: l.programEditorExerciseSearch,
                          prefixIcon: const Icon(Icons.search, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ActionButton(
                      label: l.actionCancel,
                      onPressed: widget.onCancelAdd,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ActionButton(
                      label: l.programEditorAdd,
                      primary: true,
                      onPressed: widget.onConfirmAdd,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final type in kRoutineTypes)
                      ChoiceChip(
                        key: ValueKey<String>('custom-exercise-category-$type'),
                        label: Text(type),
                        selected: widget.exerciseType == type,
                        onSelected: (_) => widget.onExerciseTypeChanged(type),
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.borderStrong),
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          color: widget.exerciseType == type
                              ? AppColors.primaryForeground
                              : AppColors.mutedForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            )
          else
            ActionButton(
              label: l.programEditorAddExercise,
              icon: Icons.add,
              onPressed: widget.onStartAdd,
            ),
        ],
      ),
    );
  }

  Widget _buildSessionName() {
    if (!_editingName) {
      return Text(
        widget.session.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      );
    }
    return TextFormField(
      key: ValueKey<String>('session-name-${widget.session.id}'),
      initialValue: widget.session.name,
      onChanged: widget.onNameChanged,
      autofocus: true,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.borderStrong),
        ),
      ),
    );
  }

  void _handleSessionAction(String action) {
    switch (action) {
      case 'edit':
        setState(() => _editingName = true);
        return;
      case 'up':
        widget.onMoveUp();
        return;
      case 'down':
        widget.onMoveDown();
        return;
      case 'delete':
        widget.onDelete();
        return;
    }
  }
}

class _ExerciseEditor extends StatefulWidget {
  const _ExerciseEditor({
    super.key,
    required this.exercise,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final ProgramExerciseDraft exercise;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<ProgramExerciseDraft> onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  State<_ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<_ExerciseEditor> {
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final exercise = widget.exercise;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.drag_indicator,
                size: 16,
                color: AppColors.subtleForeground,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: _ExerciseSummary(exercise: exercise)),
              if (exercise.source == 'trainer') ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.all(AppRadius.pill),
                  ),
                  child: Text(
                    l.coachTrainerAdded,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (_editing)
                IconButton(
                  key: ValueKey<String>('exercise-edit-${exercise.id}'),
                  tooltip: l.actionClose,
                  onPressed: () => setState(() => _editing = false),
                  icon: const Icon(Icons.check, size: 17),
                  color: AppColors.primary,
                )
              else
                PopupMenuButton<String>(
                  key: ValueKey<String>('exercise-edit-${exercise.id}'),
                  tooltip: l.actionEdit,
                  icon: const Icon(Icons.more_horiz, size: 19),
                  onSelected: _handleExerciseAction,
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: _MenuLabel(
                        icon: Icons.edit_outlined,
                        label: l.actionEdit,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'up',
                      enabled: widget.canMoveUp,
                      child: _MenuLabel(
                        icon: Icons.keyboard_arrow_up,
                        label: l.programEditorExerciseUp,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'down',
                      enabled: widget.canMoveDown,
                      child: _MenuLabel(
                        icon: Icons.keyboard_arrow_down,
                        label: l.programEditorExerciseDown,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: _MenuLabel(
                        icon: Icons.delete_outline,
                        label: l.actionDelete,
                        destructive: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_editing) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _DraftField(
              fieldId: '${exercise.id}-name',
              label: l.programEditorExercise,
              value: exercise.name,
              width: double.infinity,
              onChanged: (value) =>
                  widget.onChanged(exercise.copyWith(name: value)),
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      _metric(
                        '${exercise.id}-sets',
                        l.programEditorSets,
                        exercise.sets,
                        (v) => exercise.copyWith(sets: v),
                      ),
                      _metric(
                        '${exercise.id}-reps',
                        l.programEditorReps,
                        exercise.reps,
                        (v) => exercise.copyWith(reps: v),
                      ),
                      _metric(
                        '${exercise.id}-weight',
                        l.programEditorWeight,
                        exercise.weight,
                        (v) => exercise.copyWith(weight: v),
                      ),
                      _metric(
                        '${exercise.id}-duration',
                        l.programEditorDuration,
                        exercise.duration,
                        (v) => exercise.copyWith(duration: v),
                      ),
                      _metric(
                        '${exercise.id}-distance',
                        l.programEditorDistance,
                        exercise.distance,
                        (v) => exercise.copyWith(distance: v),
                      ),
                      _metric(
                        '${exercise.id}-rest',
                        l.programEditorRest,
                        exercise.rest,
                        (v) => exercise.copyWith(rest: v),
                      ),
                      _metric(
                        '${exercise.id}-rpe',
                        'RPE',
                        exercise.rpe,
                        (v) => exercise.copyWith(rpe: v),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _DraftField(
                    fieldId: '${exercise.id}-memo',
                    label: l.programEditorExerciseMemo,
                    value: exercise.memo,
                    width: constraints.maxWidth,
                    onChanged: (value) =>
                        widget.onChanged(exercise.copyWith(memo: value)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(
    String fieldId,
    String label,
    String value,
    ProgramExerciseDraft Function(String) update,
  ) => _DraftField(
    fieldId: fieldId,
    label: label,
    value: value,
    width: 82,
    onChanged: (next) => widget.onChanged(update(next)),
  );

  void _handleExerciseAction(String action) {
    switch (action) {
      case 'edit':
        setState(() => _editing = true);
        return;
      case 'up':
        widget.onMoveUp();
        return;
      case 'down':
        widget.onMoveDown();
        return;
      case 'delete':
        widget.onDelete();
        return;
    }
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.destructive : AppColors.foreground;
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: TextStyle(color: color, fontSize: 12.5)),
      ],
    );
  }
}

class _ExerciseSummary extends StatelessWidget {
  const _ExerciseSummary({required this.exercise});

  final ProgramExerciseDraft exercise;

  @override
  Widget build(BuildContext context) {
    final korean = Localizations.localeOf(context).languageCode == 'ko';
    final metrics = _exerciseMetrics(exercise, korean: korean);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          exercise.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        if (metrics.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            metrics.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (exercise.memo.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            exercise.memo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.subtleForeground,
              fontSize: 10.5,
            ),
          ),
        ],
      ],
    );
  }
}

List<String> _exerciseMetrics(
  ProgramExerciseDraft exercise, {
  required bool korean,
}) {
  final metrics = <String>[];
  if (exercise.sets.isNotEmpty && exercise.reps.isNotEmpty) {
    metrics.add(
      korean
          ? '${exercise.sets}세트 × ${exercise.reps}회'
          : '${exercise.sets} sets × ${exercise.reps} reps',
    );
  } else if (exercise.sets.isNotEmpty) {
    metrics.add(korean ? '${exercise.sets}세트' : '${exercise.sets} sets');
  } else if (exercise.reps.isNotEmpty) {
    metrics.add(korean ? '${exercise.reps}회' : '${exercise.reps} reps');
  }
  if (exercise.weight.isNotEmpty) {
    metrics.add('${exercise.weight}kg');
  }
  if (exercise.duration.isNotEmpty) {
    metrics.add(korean ? '${exercise.duration}분' : '${exercise.duration} min');
  }
  if (exercise.distance.isNotEmpty) {
    metrics.add('${exercise.distance}m');
  }
  if (exercise.rest.isNotEmpty) {
    metrics.add(korean ? '휴식 ${exercise.rest}초' : 'Rest ${exercise.rest} sec');
  }
  if (exercise.rpe.isNotEmpty) {
    metrics.add('RPE ${exercise.rpe}');
  }
  return metrics;
}

class _DraftField extends StatelessWidget {
  const _DraftField({
    required this.fieldId,
    required this.label,
    required this.value,
    required this.width,
    required this.onChanged,
  });

  final String fieldId;
  final String label;
  final String value;
  final double width;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey<String>(fieldId),
        initialValue: value,
        onChanged: onChanged,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            7,
          ),
          labelStyle: const TextStyle(
            color: AppColors.subtleForeground,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.borderStrong),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.primary, width: 1.25),
          ),
        ),
      ),
    );
  }
}
