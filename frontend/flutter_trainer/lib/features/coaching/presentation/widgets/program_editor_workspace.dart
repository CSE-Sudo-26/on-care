import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// Rich local draft editor matching the Figma program workspace.
///
/// Multi-session persistence remains unsupported. A one-session draft can be
/// handed to the existing flat routine boundary through the supplied actions.
///
/// **이 편집기는 회원에게 아무것도 보내지 않는다 (#1028).** 예전에는 여기에
/// `배정`·`PT 등록` 버튼이 나란히 있어, 편집 중 아무 때나 실제 전송이
/// 일어날 수 있었다. 이제 이 화면의 마지막 동작은 [onReview] — 지금 구성의
/// **스냅샷**을 최종 검토 단계로 넘기는 것뿐이고, 실제 배정·등록은 그
/// 단계에서만 일어난다. 그래서 이 파일에는 repository 호출이 하나도 없다.
class ProgramEditorWorkspace extends StatefulWidget {
  const ProgramEditorWorkspace({
    super.key,
    required this.clientGoal,
    required this.aiSuggestions,
    required this.onReview,
    this.template,
    this.templateRevision = 0,
    this.initialDraft,
    this.onSave,
    this.saving = false,
  });

  final String clientGoal;
  final List<AiRoutineItem> aiSuggestions;
  final ProgramTemplate? template;
  final int templateRevision;

  /// 지금 구성을 최종 검토 단계로 넘긴다. **전송이 아니다** — 넘어간 값이
  /// 그대로 검토 화면에 그려지고, 전송은 거기서만 할 수 있다 (#1028).
  final ValueChanged<ProgramEditorState> onReview;

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

  @override
  State<ProgramEditorWorkspace> createState() => _ProgramEditorWorkspaceState();
}

class _ProgramEditorWorkspaceState extends State<ProgramEditorWorkspace> {
  late ProgramEditorState _draft;
  var _initialized = false;
  var _editingProgramInfo = false;
  final TextEditingController _programName = TextEditingController();
  String? _addingToSession;
  final TextEditingController _exerciseName = TextEditingController();
  String _newExerciseType = '근력';
  // [ProgramExerciseDraft] 의 기본값과 맞춘다 — 추가 폼에서 비워 두면 그
  // 기본값 그대로 나간다. 세트·횟수는 근력일 때만, 시간은 그 외 유형일
  // 때만 보인다(#1029) — 유형이 무엇을 재는 운동인지가 다르기 때문이다.
  String _newExerciseSets = '3';
  String _newExerciseReps = '10';
  String _newExerciseDuration = '';
  var _nextId = 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final l = AppLocalizations.of(context);
    final saved = widget.initialDraft;
    if (saved != null) {
      _draft = saved;
      _nextId =
          saved.sessions.fold<int>(
            0,
            (count, session) => count + session.exercises.length,
          ) +
          2;
    } else {
      // AI 루틴을 생성하기 전에는 임의의 추천 내용으로 채우지 않는다 — 프로그램
      // 정보 박스는 빈 상태로 시작하고, 이후 "템플릿에 반영"(AI 루틴 생성
      // 플로우) 또는 아래 AI 힌트 배너의 "편집기에 반영"을 눌러야만 채워진다.
      _draft = ProgramEditorState.initial(
        clientGoal: widget.clientGoal,
        programName: l.programEditorDefaultName(widget.clientGoal),
        sessionName: l.programEditorDefaultSession,
      );
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _programName.dispose();
    _exerciseName.dispose();
    super.dispose();
  }

  /// 프로그램 이름 편집 UI — 카드 제목 자리에서 직접 뜬다. 깃허브 이슈/PR
  /// 제목처럼: 평소엔 이름 옆에 연필 아이콘만 있고, 누르면 그 자리가 입력칸
  /// 으로 바뀐다. 저장/취소 버튼은 옆의 카드 헤더 오른쪽(평소 `저장`/`검토
  /// 하기` 버튼이 있는 자리)으로 옮겨 보여준다(`_headerActions`) — 입력칸
  /// 아래에 따로 두면 카드 폭이 좁을 때 버튼이 다음 줄로 밀렸다. 목표·기간·
  /// 메모까지 담던 예전 `_ProgramInfo` 는 실제 배정·PT 등록 payload 가
  /// 읽지 않아 뺐고(#1029), 이름만 남았다.
  Widget _programNameTitle(AppLocalizations l) {
    const titleStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w800,
      color: AppColors.foreground,
    );
    if (!_editingProgramInfo) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              _draft.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            key: const ValueKey<String>('program-info-edit'),
            tooltip: l.actionEdit,
            onPressed: () => setState(() {
              _programName.text = _draft.name;
              _editingProgramInfo = true;
            }),
            icon: const Icon(Icons.edit_outlined, size: 15),
            color: AppColors.subtleForeground,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
          ),
        ],
      );
    }

    return TextField(
      key: const ValueKey<String>('program-name-inline-field'),
      controller: _programName,
      autofocus: true,
      style: titleStyle,
      onSubmitted: (_) => _saveProgramName(),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.sm),
        ),
      ),
    );
  }

  void _saveProgramName() {
    final value = _programName.text.trim();
    setState(() {
      if (value.isNotEmpty) {
        _update(_draft.copyWith(name: value));
      }
      _editingProgramInfo = false;
    });
  }

  /// 카드 헤더 오른쪽 자리 — 평소엔 `저장`/`검토하기`, 이름을 고치는
  /// 동안에는 그 자리를 그대로 `취소`/`저장`으로 바꿔 쓴다.
  Widget _headerActions(AppLocalizations l) {
    if (_editingProgramInfo) {
      return Wrap(
        spacing: AppSpacing.xs,
        children: <Widget>[
          TextButton(
            key: const ValueKey<String>('program-info-cancel'),
            onPressed: () => setState(() => _editingProgramInfo = false),
            child: Text(l.actionCancel),
          ),
          ActionButton(
            key: const ValueKey<String>('program-info-save'),
            label: l.actionSave,
            primary: true,
            onPressed: _saveProgramName,
          ),
        ],
      );
    }
    final canReview = _draft.supportsAssignment;
    final canSave = widget.onSave != null && _draft.name.trim().isNotEmpty;
    return Wrap(
      spacing: AppSpacing.xs,
      children: <Widget>[
        Tooltip(
          message: canSave ? '' : l.programEditorSaveUnsupported,
          child: ActionButton(
            key: const ValueKey<String>('program-editor-save'),
            // 몇 번을 눌러도 항상 `저장` 이다 — 이 버튼은 지금 구성을
            // 프로그램 템플릿으로 새로 저장하는 동작이라 "고친 걸 다시
            // 저장"이라는 의미의 `수정 저장` 표시가 맞지 않는다.
            label: widget.saving ? l.progSaving : l.actionSave,
            onPressed: canSave && !widget.saving
                ? () => widget.onSave!(_draft)
                : null,
          ),
        ),
        // 저장 옆에 있던 `고객에게 배정` 이 있던 자리다. 이제는 전송이
        // 아니라 **최종 검토로 넘어가는** 동작이라, 저장과 나란히 있어도
        // 둘 다 회원에게 아무것도 보내지 않는다 (#1028).
        Tooltip(
          message: canReview ? '' : l.programEditorAssignUnsupported,
          child: ActionButton(
            key: const ValueKey<String>('program-editor-review'),
            label: l.programEditorReview,
            primary: true,
            onPressed: canReview ? () => widget.onReview(_draft) : null,
          ),
        ),
      ],
    );
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
    // `showDialog` 는 다음 프레임(세션 목록이 이미 그려진 뒤)까지 미룬다 —
    // `didUpdateWidget` 은 build 도중이라 그 자리에서 바로 다이얼로그를 열
    // 수 없다. `didUpdateWidget` 자체는 동기 함수라 여기서 기다리지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 프레임이 끝난 뒤에야 불린다 — 그 사이 고객 전환 등으로 이 State 가
      // 트리에서 빠졌다면 dispose 된 State 에서 context/setState 를 건드리게
      // 된다.
      if (!mounted) return;
      unawaited(_applyTemplateToSession(template));
    });
  }

  /// 템플릿을 세션에 덧붙인다(#1029) — 세션이 둘 이상이면 어느 세션에
  /// 넣을지 먼저 고르게 한다. 하나뿐이면 고를 것이 없으니 곧장 그 세션에
  /// 붙인다. 기존 운동은 지우지 않고 그 세션의 목록 뒤에 이어 붙인다.
  Future<void> _applyTemplateToSession(ProgramTemplate template) async {
    var targetIndex = 0;
    if (_draft.sessions.length > 1) {
      final chosen = await _pickTemplateTargetSession(template);
      if (chosen == null || !mounted) return;
      targetIndex = chosen;
    }
    // 다이얼로그를 기다리는 동안 세션이 지워졌을 수 있다 — 인덱스를 다시
    // 확인한다.
    if (targetIndex >= _draft.sessions.length) return;
    final target = _draft.sessions[targetIndex];
    final additions = <ProgramExerciseDraft>[
      for (final exercise in template.exercises)
        ProgramExerciseDraft(
          id: 'exercise-${_nextId++}',
          name: exercise.name,
          duration: '${exercise.minutes}',
          type: exercise.type,
          sets: exercise.sets > 0 ? '${exercise.sets}' : '3',
          reps: exercise.reps.isNotEmpty ? exercise.reps : '10',
          // `source` 는 그대로 서버 계약값(`trainer`)으로 남긴다 — 출처
          // 배지만 이 값을 우선해서 `<템플릿명> 템플릿 추가` 를 보여 준다.
          templateName: template.name,
        ),
    ];
    _replaceSession(
      targetIndex,
      target.copyWith(
        exercises: <ProgramExerciseDraft>[...target.exercises, ...additions],
      ),
    );
  }

  Future<int?> _pickTemplateTargetSession(ProgramTemplate template) {
    final l = AppLocalizations.of(context);
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('template-session-picker'),
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
        title: Text(
          l.programTemplateSessionPickerTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l.programTemplateSessionPickerBody(template.name),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtleForeground,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < _draft.sessions.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                ActionButton(
                  key: ValueKey<String>(
                    'template-session-picker-${_draft.sessions[i].id}',
                  ),
                  label: _draft.sessions[i].name,
                  onPressed: () => Navigator.of(dialogContext).pop(i),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('template-session-picker-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.actionCancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: _draft.name,
      titleWidget: _programNameTitle(l),
      dense: true,
      trailing: _headerActions(l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // `프로그램 정보`(목표·기간·메모 입력)는 뺐다(#1029) — 실제 배정·
          // PT 등록 payload(`programAssignToJson`/`_draftProgram`)는 이름과
          // 세션만 쓰고 이 값들을 읽지 않는다. `goal` 은 여전히 템플릿 저장
          // (`_saveTemplate`)에 쓰이므로 필드 자체([ProgramEditorState.goal])
          // 는 남기고, 고객의 목표로 자동 채워진 값을 그대로 쓴다 — 안내
          // 배너 없이도 AI 흐름의 `템플릿에 반영`이 그 값을 그대로 세션
          // 1에 병합한다(didUpdateWidget).
          //
          // 이름만은 계속 고칠 수 있어야 한다 — 카드 제목([SectionCard.title])
          // 이자 템플릿 저장 이름이라, 자동 생성된 문구(`OOO님을 위한
          // 프로그램`) 그대로 저장되는 유일한 경로가 되면 안 된다. 편집
          // UI는 이제 카드 제목 자리에서 바로 뜬다(`_programNameTitle`,
          // 깃허브 이슈/PR 제목 수정과 같은 자리 전환 방식).
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
              exerciseSets: _newExerciseSets,
              exerciseReps: _newExerciseReps,
              exerciseDuration: _newExerciseDuration,
              onNameChanged: (value) => _replaceSession(
                index,
                _draft.sessions[index].copyWith(name: value),
              ),
              onMoveUp: () => _moveSession(index, -1),
              onMoveDown: () => _moveSession(index, 1),
              onDelete: () => _deleteSession(index),
              onReset: () => _resetSession(index),
              onStartAdd: () => setState(() {
                _addingToSession = _draft.sessions[index].id;
                _exerciseName.clear();
              }),
              onCancelAdd: _cancelExerciseAdd,
              onExerciseTypeChanged: (type) =>
                  setState(() => _newExerciseType = type),
              onExerciseSetsChanged: (value) =>
                  setState(() => _newExerciseSets = value),
              onExerciseRepsChanged: (value) =>
                  setState(() => _newExerciseReps = value),
              onExerciseDurationChanged: (value) =>
                  setState(() => _newExerciseDuration = value),
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
          // `오늘 PT 스케줄에 등록` 과 날짜 칩은 최종 검토 단계로 옮겼다 —
          // 편집 도중에 일정이 잡히는 일이 더는 없다 (#1028).
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

  /// 이 세션의 운동만 비운다(#1029) — 세션 자체와 다른 세션은 그대로 둔다.
  void _resetSession(int index) {
    _replaceSession(
      index,
      _draft.sessions[index].copyWith(exercises: const <ProgramExerciseDraft>[]),
    );
  }

  void _addExercise(int sessionIndex) {
    final name = _exerciseName.text.trim();
    if (name.isEmpty) return;
    final isStrength = _newExerciseType == '근력';
    final sets = _newExerciseSets.trim();
    final reps = _newExerciseReps.trim();
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
            // 근력만 세트·횟수를 실제로 받는다(#1029) — 그 외 유형은 시간을
            // 쓴다. 비우면 [ProgramExerciseDraft] 기본값(3세트·10회)을 그대로
            // 쓴다 — 빈 문자열이 남으면 배정 계약(`supportsAssignment`)이 이
            // 운동을 막는다.
            sets: isStrength && sets.isNotEmpty ? sets : '3',
            reps: isStrength && reps.isNotEmpty ? reps : '10',
            duration: isStrength ? '' : _newExerciseDuration.trim(),
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
      _newExerciseReps = '10';
      _newExerciseSets = '3';
      _newExerciseDuration = '';
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
            // 2단계에서 직접 채운 세트/횟수가 있으면 그대로 옮긴다 — 없으면
            // [ProgramExerciseDraft] 기본값(3세트·10회)을 그대로 둔다.
            sets: item.sets > 0 ? '${item.sets}' : '3',
            reps: item.reps.isNotEmpty ? item.reps : '10',
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
    required this.exerciseSets,
    required this.exerciseReps,
    required this.exerciseDuration,
    required this.onNameChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onReset,
    required this.onStartAdd,
    required this.onCancelAdd,
    required this.onExerciseTypeChanged,
    required this.onExerciseSetsChanged,
    required this.onExerciseRepsChanged,
    required this.onExerciseDurationChanged,
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
  final String exerciseSets;
  final String exerciseReps;
  final String exerciseDuration;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  /// 이 세션의 운동만 비운다 — 세션 자체는 남는다(#1029).
  final VoidCallback onReset;
  final VoidCallback onStartAdd;
  final VoidCallback onCancelAdd;
  final ValueChanged<String> onExerciseTypeChanged;
  final ValueChanged<String> onExerciseSetsChanged;
  final ValueChanged<String> onExerciseRepsChanged;
  final ValueChanged<String> onExerciseDurationChanged;
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
              else ...<Widget>[
                // 더보기 메뉴 안에 묻으면 잘 안 보인다 — 초기화만 따로 아이콘
                // 버튼으로 더보기 왼쪽에 둔다.
                IconButton(
                  key: ValueKey<String>('session-reset-${widget.session.id}'),
                  tooltip: l.programEditorSessionReset,
                  onPressed: widget.session.exercises.isEmpty
                      ? null
                      : () => unawaited(_confirmReset()),
                  icon: const Icon(Icons.refresh, size: 18),
                  color: AppColors.subtleForeground,
                  disabledColor: AppColors.disabledForeground,
                  visualDensity: VisualDensity.compact,
                ),
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
            ],
          ),
          if (widget.session.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                l.programEditorSessionEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
            // 새로 추가 중인 한 줄도 이미 있는 운동 카드와 같은 틀(카드 배경·
            // 테두리·반경)을 쓴다 — 그래야 목록에 자연스럽게 이어 붙는 한 줄로
            // 보이고, 입력 글자 크기도 [_DraftField] 와 맞춘다.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: const BorderRadius.all(AppRadius.md),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const ValueKey<String>('custom-exercise-name'),
                          controller: widget.exerciseNameController,
                          autofocus: true,
                          onSubmitted: (_) => widget.onConfirmAdd(),
                          style: const TextStyle(
                            color: AppColors.foreground,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: l.programEditorExerciseSearch,
                            hintStyle: const TextStyle(
                              color: AppColors.subtleForeground,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 17,
                              color: AppColors.subtleForeground,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.card,
                            contentPadding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.sm,
                              AppSpacing.sm,
                              7,
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
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.25,
                              ),
                            ),
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
                  const SizedBox(height: AppSpacing.sm),
                  // 운동 카드 안 유형 선택과 같은 컴포넌트(회원 앱 운동 추가
                  // 시트와도 같다) — 여기만 따로 만든 칩을 쓰지 않는다. 유형을
                  // 먼저 골라야 아래 입력칸이 세트·횟수인지 시간인지 정해진다.
                  RoutineCategoryChips(
                    keyPrefix: 'custom-exercise-category',
                    value: widget.exerciseType,
                    onChanged: widget.onExerciseTypeChanged,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 근력은 세트·횟수로, 그 외 유형은 시간으로 잰다(#1029) —
                  // 무엇을 재는 운동인지가 유형마다 달라 같은 칸을 쓰지 않는다.
                  // 필드는 운동 카드 수정 모드([_metric])와 같은 [_DraftField]
                  // 다. `stretch` Column 의 직계 자식이면 지정한 width 가
                  // 무시되고 카드 끝까지 늘어나므로 `Align`/`Row` 로 감싼다.
                  if (widget.exerciseType == '근력')
                    Row(
                      children: <Widget>[
                        _DraftField(
                          fieldId: 'custom-exercise-sets',
                          label: l.programEditorSets,
                          value: widget.exerciseSets,
                          width: 90,
                          onChanged: widget.onExerciseSetsChanged,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _DraftField(
                          fieldId: 'custom-exercise-reps',
                          label: l.programEditorReps,
                          value: widget.exerciseReps,
                          width: 90,
                          onChanged: widget.onExerciseRepsChanged,
                        ),
                      ],
                    )
                  else
                    // 시·분으로 나눠 받지만 저장값은 그대로 `duration`(총 분)
                    // 하나다 — [_DurationField] 참고.
                    _DurationField(
                      fieldId: 'custom-exercise-duration',
                      totalMinutes: widget.exerciseDuration,
                      onChanged: widget.onExerciseDurationChanged,
                    ),
                ],
              ),
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

  /// 운동이 있을 때만 묻는다 — 초기화 아이콘 자체가 그때만 활성화되니, 이
  /// 액션이 불릴 때는 지울 것이 있다는 뜻이다.
  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('session-reset-confirm'),
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
        title: Text(
          l.programEditorSessionResetTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        content: Text(
          l.programEditorSessionResetBody(widget.session.name),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('session-reset-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('session-reset-submit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.programEditorSessionReset),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onReset();
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
              // 템플릿에서 끌어온 운동은 `<템플릿명> 템플릿 추가` 로, 그 외
              // 직접 추가는 `트레이너 추가` 로 — `source` 는 그대로 서버
              // 계약값(`trainer`)이라 [templateName] 이 있을 때만 우선한다
              // (#1029).
              if (exercise.templateName != null || exercise.source == 'trainer') ...<Widget>[
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
                    exercise.templateName != null
                        ? l.coachTemplateAdded(exercise.templateName!)
                        : l.coachTrainerAdded,
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
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      // 세트·횟수는 근력에서만 잰다(#1029) — 그 외 유형은
                      // 요약(`programExerciseMetrics`)이 이 값을 읽지 않아,
                      // 여기서 계속 입력받으면 "입력했는데 사라졌다"로
                      // 보인다.
                      if (exercise.type == '근력') ...<Widget>[
                        _metric(
                          '${exercise.id}-sets',
                          l.programEditorSets,
                          exercise.sets,
                          (v) => exercise.copyWith(sets: v),
                          width: 90,
                        ),
                        _metric(
                          '${exercise.id}-reps',
                          l.programEditorReps,
                          exercise.reps,
                          (v) => exercise.copyWith(reps: v),
                        ),
                      ],
                      _metric(
                        '${exercise.id}-weight',
                        l.programEditorWeight,
                        exercise.weight,
                        (v) => exercise.copyWith(weight: v),
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
                  const SizedBox(height: AppSpacing.sm),
                  // 시·분으로 나눠 받지만 저장값은 그대로 `duration`(총 분)
                  // 하나다 — [_DurationField] 참고.
                  _DurationField(
                    fieldId: '${exercise.id}-duration',
                    totalMinutes: exercise.duration,
                    onChanged: (value) =>
                        widget.onChanged(exercise.copyWith(duration: value)),
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
    ProgramExerciseDraft Function(String) update, {
    double width = 82,
  }) => _DraftField(
    fieldId: fieldId,
    label: label,
    value: value,
    width: width,
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
    final metrics = programExerciseMetrics(exercise, korean: korean);
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

/// 운동 한 줄의 지표 요약(세트·횟수·중량·시간·거리·휴식·RPE).
///
/// 최종 검토 화면이 같은 함수를 쓴다 (#1028) — 검토 화면이 편집기와 다른
/// 방식으로 값을 그리면, 트레이너가 확인한 내용과 실제로 나가는 payload 가
/// 어긋났는지 눈으로는 알 수 없다.
List<String> programExerciseMetrics(
  ProgramExerciseDraft exercise, {
  required bool korean,
}) {
  final metrics = <String>[];
  // 세트·횟수는 근력에서만 잰다(#1029) — 그 외 유형(유산소·스트레칭·기타)은
  // 시간으로 잰다. 템플릿을 세션에 붙일 때는 백엔드 계약(양수 필수)을
  // 맞추려 모든 운동에 기본 세트·횟수를 채워 두므로(`_applyTemplateToSession`),
  // 값이 있다고 그대로 보여주면 비근력 운동에도 세트·횟수가 뜬다.
  if (exercise.type == '근력') {
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

/// 운동 시간을 시·분으로 나눠 받는다 — 저장값은 그대로
/// [ProgramExerciseDraft.duration] 하나(총 분)다. 새 필드를 만들지 않고,
/// 입력 UI에서만 시·분으로 쪼개고(표시) 합친다(저장: `hour*60 + minute`).
class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.fieldId,
    required this.totalMinutes,
    required this.onChanged,
  });

  /// Base id — hour/minute boxes key off `$fieldId-hour`/`$fieldId-minute`.
  final String fieldId;

  /// The stored value — total minutes as a string, or empty when unset.
  final String totalMinutes;

  /// Called with the recomputed total minutes (as a string) whenever either
  /// box changes.
  final ValueChanged<String> onChanged;

  static const TextStyle _unitLabelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.subtleForeground,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = int.tryParse(totalMinutes.trim());
    final hour = total == null ? null : total ~/ 60;
    final minute = total == null ? null : total % 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.routineFieldMinutes,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            _unitBox(
              fieldKey: ValueKey<String>('$fieldId-hour'),
              value: hour?.toString() ?? '',
              onChanged: (value) => onChanged(
                ((int.tryParse(value) ?? 0) * 60 + (minute ?? 0)).toString(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(l.schedHourSuffix, style: _unitLabelStyle),
            const SizedBox(width: AppSpacing.sm),
            _unitBox(
              fieldKey: ValueKey<String>('$fieldId-minute'),
              value: minute?.toString() ?? '',
              maxValue: 59,
              onChanged: (value) => onChanged(
                ((hour ?? 0) * 60 + (int.tryParse(value) ?? 0)).toString(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(l.schedMinuteSuffix, style: _unitLabelStyle),
          ],
        ),
      ],
    );
  }

  /// 세트·반복수 칸([_DraftField])과 같은 높이·반경·타이포를 쓰는 숫자 전용
  /// 칸 — 다만 라벨은 칸 안이 아니라 옆에 "시간"/"분"으로 붙는다.
  Widget _unitBox({
    required Key fieldKey,
    required String value,
    required ValueChanged<String> onChanged,
    int? maxValue,
  }) {
    return SizedBox(
      width: 56,
      child: TextFormField(
        key: fieldKey,
        initialValue: value,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
          if (maxValue != null)
            TextInputFormatter.withFunction((oldValue, newValue) {
              if (newValue.text.isEmpty) return newValue;
              final parsed = int.tryParse(newValue.text);
              if (parsed == null || parsed > maxValue) return oldValue;
              return newValue;
            }),
        ],
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(
            color: AppColors.subtleForeground,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.card,
          contentPadding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            7,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.borderStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.primary, width: 1.25),
          ),
        ),
      ),
    );
  }
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
