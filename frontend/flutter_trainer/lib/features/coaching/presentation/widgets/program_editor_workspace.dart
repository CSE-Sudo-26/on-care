import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// Rich local draft editor matching the Figma program workspace.
///
/// BACKEND_REQUIRED: no action in this widget claims to save or assign a
/// multi-session program. The existing flat-routine delivery remains outside
/// this widget until a dedicated Program API exists.
class ProgramEditorWorkspace extends StatefulWidget {
  const ProgramEditorWorkspace({
    super.key,
    required this.clientGoal,
    required this.aiSuggestions,
  });

  final String clientGoal;
  final List<AiRoutineItem> aiSuggestions;

  @override
  State<ProgramEditorWorkspace> createState() => _ProgramEditorWorkspaceState();
}

class _ProgramEditorWorkspaceState extends State<ProgramEditorWorkspace> {
  late ProgramEditorState _draft = ProgramEditorState.initial(
    widget.clientGoal,
  );
  String? _addingToSession;
  final TextEditingController _exerciseName = TextEditingController();
  var _nextId = 2;

  @override
  void dispose() {
    _exerciseName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: _draft.name,
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: <Widget>[
          Tooltip(
            message: '다중 세션 프로그램 저장 API가 아직 없어요.',
            child: const ActionButton(label: '저장', onPressed: null),
          ),
          Tooltip(
            message: '현재 서버는 평면 루틴 배정만 지원해요.',
            child: const ActionButton(
              label: '회원에게 배정',
              primary: true,
              onPressed: null,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _UnsupportedBanner(),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '프로그램 정보',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _DraftField(
                label: '프로그램명',
                value: _draft.name,
                width: 220,
                onChanged: (value) => _update(_draft.copyWith(name: value)),
              ),
              _DraftField(
                label: '목표 (선택)',
                value: _draft.goal,
                width: 180,
                onChanged: (value) => _update(_draft.copyWith(goal: value)),
              ),
              _DraftField(
                label: '기간 (선택)',
                value: _draft.period,
                width: 150,
                onChanged: (value) => _update(_draft.copyWith(period: value)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DraftField(
            label: '프로그램 메모 (선택)',
            value: _draft.memo,
            width: double.infinity,
            onChanged: (value) => _update(_draft.copyWith(memo: value)),
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
                  const Expanded(
                    child: Text(
                      'AI 코칭 보조 제안을 첫 세션에 로컬 초안으로 반영할 수 있어요.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ActionButton(
                    label: '편집기에 반영',
                    onPressed: _applyAiSuggestions,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '운동 구성',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              ActionButton(
                label: '세션 추가',
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
    final id = 'session-${_nextId++}';
    _update(
      _draft.copyWith(
        sessions: <ProgramSessionDraft>[
          ..._draft.sessions,
          ProgramSessionDraft(
            id: id,
            name: '세션 ${String.fromCharCode(64 + _draft.sessions.length + 1)}',
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
          ProgramExerciseDraft(id: 'exercise-${_nextId++}', name: name),
        ],
      ),
    );
    _cancelExerciseAdd();
  }

  void _cancelExerciseAdd() {
    setState(() {
      _addingToSession = null;
      _exerciseName.clear();
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

  void _applyAiSuggestions() {
    final first = _draft.sessions.first;
    final existingNames = first.exercises.map((item) => item.name).toSet();
    final additions = <ProgramExerciseDraft>[
      for (final item in widget.aiSuggestions)
        if (!existingNames.contains(item.name))
          ProgramExerciseDraft(
            id: 'exercise-${_nextId++}',
            name: item.name,
            duration: '${item.minutes}',
            memo: item.reason,
          ),
    ];
    if (additions.isEmpty) return;
    _replaceSession(
      0,
      first.copyWith(
        exercises: <ProgramExerciseDraft>[...first.exercises, ...additions],
      ),
    );
  }
}

class _UnsupportedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.info_outline, color: AppColors.warning, size: 17),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '로컬 편집 상태입니다. 다중 세션 저장·배정은 신규 Program API 연결 후 사용할 수 있어요.',
              style: TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionEditor extends StatelessWidget {
  const _SessionEditor({
    super.key,
    required this.session,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.addingExercise,
    required this.exerciseNameController,
    required this.onNameChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onStartAdd,
    required this.onCancelAdd,
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
  final ValueChanged<String> onNameChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onStartAdd;
  final VoidCallback onCancelAdd;
  final VoidCallback onConfirmAdd;
  final void Function(int, ProgramExerciseDraft) onExerciseChanged;
  final void Function(int, int) onMoveExercise;
  final ValueChanged<int> onDeleteExercise;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: TextFormField(
                  key: ValueKey<String>('session-name-${session.id}'),
                  initialValue: session.name,
                  onChanged: onNameChanged,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                tooltip: '세션 위로 이동',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              ),
              IconButton(
                tooltip: '세션 아래로 이동',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
              IconButton(
                tooltip: '세션 삭제',
                onPressed: canDelete ? onDelete : null,
                color: AppColors.destructive,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          if (session.exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '운동을 추가해 세션을 구성하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subtleForeground,
                  fontSize: 12,
                ),
              ),
            ),
          for (
            var index = 0;
            index < session.exercises.length;
            index++
          ) ...<Widget>[
            _ExerciseEditor(
              exercise: session.exercises[index],
              canMoveUp: index > 0,
              canMoveDown: index < session.exercises.length - 1,
              onChanged: (value) => onExerciseChanged(index, value),
              onMoveUp: () => onMoveExercise(index, -1),
              onMoveDown: () => onMoveExercise(index, 1),
              onDelete: () => onDeleteExercise(index),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (addingExercise)
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: exerciseNameController,
                    autofocus: true,
                    onSubmitted: (_) => onConfirmAdd(),
                    decoration: const InputDecoration(
                      hintText: '운동 이름 검색 또는 직접 입력',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ActionButton(label: '취소', onPressed: onCancelAdd),
                const SizedBox(width: AppSpacing.xs),
                ActionButton(
                  label: '추가',
                  primary: true,
                  onPressed: onConfirmAdd,
                ),
              ],
            )
          else
            ActionButton(
              label: '운동 추가',
              icon: Icons.add,
              onPressed: onStartAdd,
            ),
        ],
      ),
    );
  }
}

class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.drag_indicator,
                size: 16,
                color: AppColors.subtleForeground,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _DraftField(
                  label: '운동',
                  value: exercise.name,
                  width: double.infinity,
                  onChanged: (value) =>
                      onChanged(exercise.copyWith(name: value)),
                ),
              ),
              IconButton(
                tooltip: '운동 위로 이동',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              ),
              IconButton(
                tooltip: '운동 아래로 이동',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
              IconButton(
                tooltip: '운동 삭제',
                onPressed: onDelete,
                color: AppColors.destructive,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _metric('세트', exercise.sets, (v) => exercise.copyWith(sets: v)),
              _metric('횟수', exercise.reps, (v) => exercise.copyWith(reps: v)),
              _metric(
                '중량 kg',
                exercise.weight,
                (v) => exercise.copyWith(weight: v),
              ),
              _metric(
                '시간 분',
                exercise.duration,
                (v) => exercise.copyWith(duration: v),
              ),
              _metric(
                '거리 m',
                exercise.distance,
                (v) => exercise.copyWith(distance: v),
              ),
              _metric('휴식 초', exercise.rest, (v) => exercise.copyWith(rest: v)),
              _metric('RPE', exercise.rpe, (v) => exercise.copyWith(rpe: v)),
              _DraftField(
                label: '메모',
                value: exercise.memo,
                width: 180,
                onChanged: (value) => onChanged(exercise.copyWith(memo: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
    String label,
    String value,
    ProgramExerciseDraft Function(String) update,
  ) => _DraftField(
    label: label,
    value: value,
    width: 82,
    onChanged: (next) => onChanged(update(next)),
  );
}

class _DraftField extends StatelessWidget {
  const _DraftField({
    required this.label,
    required this.value,
    required this.width,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double width;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey<String>('$label-$value'),
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}
