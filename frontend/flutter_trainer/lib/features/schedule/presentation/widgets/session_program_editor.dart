import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/presentation/models/program_draft.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 세션 하나의 프로그램을 그 자리에서 고치는 편집기.
///
/// 운동 행을 [ProgramDraft] 로 들고 있다가 저장할 때 한 번에 반영한다.
class SessionProgramEditor extends ConsumerStatefulWidget {
  const SessionProgramEditor({
    required this.session,
    required this.onSaved,
    required this.onCancel,
    this.noteOnly = false,
    super.key,
  });

  final ScheduleSession session;

  /// 운동 목록 없이 **메모만** 고친다(상담). 저장할 때 기존 프로그램은 건드리지
  /// 않는다 — 편집기가 보여 주지 않은 값을 지우면 안 된다(#988).
  final bool noteOnly;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<SessionProgramEditor> createState() =>
      _SessionProgramEditorState();
}

class _SessionProgramEditorState extends ConsumerState<SessionProgramEditor> {
  late final TextEditingController _note;
  late final List<ProgramDraft> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.session.note);
    _items = widget.session.program.map(ProgramDraft.fromItem).toList();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() => _items.add(ProgramDraft.empty(l)));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (_saving) return;
    // await 전에 잡아 둔다 — 실패 경로가 await 뒤에도 있다.
    final AppLocalizations l = AppLocalizations.of(context);
    final program = <ProgramItem>[];
    for (final item in widget.noteOnly ? const <ProgramDraft>[] : _items) {
      final name = item.name.text.trim();
      final sets = int.tryParse(item.sets.text.trim());
      final durationText = item.duration.text.trim();
      final duration = durationText.isEmpty ? 0 : int.tryParse(durationText);
      if (name.isEmpty ||
          sets == null ||
          sets < 1 ||
          sets > 100 ||
          duration == null ||
          duration < 0 ||
          duration > 600) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.progInvalid)));
        return;
      }
      program.add(
        ProgramItem(
          name: name,
          sets: sets,
          reps: item.reps.text.trim().isEmpty ? '-' : item.reps.text.trim(),
          weight: item.weight.text.trim().isEmpty
              ? '-'
              : item.weight.text.trim(),
          type: item.type,
          duration: durationText,
        ),
      );
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .updateProgram(
            widget.session.id,
            program: widget.noteOnly ? widget.session.program : program,
            // 편집기가 보여 주지 않은 값은 그대로 둔다(#1011).
            note: widget.noteOnly ? _note.text.trim() : widget.session.note,
          );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.progSaveFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.noteOnly ? l.schedEditNote : l.progEditTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!widget.noteOnly) ...<Widget>[
            for (var index = 0; index < _items.length; index++) ...<Widget>[
              _ProgramDraftFields(
                index: index,
                draft: _items[index],
                onRemove: () => _removeItem(index),
                onTypeChanged: (type) =>
                    setState(() => _items[index].type = type),
                onDurationChanged: (minutes) =>
                    setState(() => _items[index].duration.text = '$minutes'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
              onPressed: _saving ? null : _addItem,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.progAddExercise),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // 메모는 **메모 자리에서만** 고친다. 프로그램 편집기 안쪽, 운동 목록을
          // 다 지나야 나오는 자리에도 두면 같은 값을 고치는 곳이 둘이 되어
          // 어느 쪽이 최신인지 읽는 사람이 알 수 없다(#1011).
          if (widget.noteOnly) ...<Widget>[
            Text(
              l.schedNote,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: const ValueKey<String>('program-trainer-note'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l.progNoteHint,
                hintStyle: const TextStyle(color: AppColors.mutedForeground),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onCancel,
                  // 좁은 화면에서 "프로그램 저장"이 두 줄로 접히던 것과
                  // 같은 안전장치 — 잘리는 대신 통째로 줄어든다.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l.actionCancel),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('save-program'),
                  onPressed: _saving ? null : _save,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_saving ? l.progSaving : l.progSaveAction),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgramDraftFields extends StatelessWidget {
  const _ProgramDraftFields({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onDurationChanged,
  });

  final int index;
  final ProgramDraft draft;
  final VoidCallback onRemove;
  final ValueChanged<String> onTypeChanged;

  /// 슬라이더를 실제로 움직였을 때만 부른다 — 비어 있는 채로 두면
  /// [ProgramDraft.duration] 은 그대로 빈 문자열로 남아 미입력을
  /// 지킨다(#1233). 슬라이더가 보여 주는 기본값(5분)은 화면 표시일 뿐,
  /// 건드리지 않으면 저장되지 않는다.
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final storedDuration = int.tryParse(draft.duration.text.trim());
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
          // 코칭 탭에서 프로그램을 짤 때와 같은 순서·같은 위젯이다 —
          // 유형을 먼저 고르고, 그 유형 안에서 이름·세트를 채운다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: RoutineCategoryChips(
                  keyPrefix: 'program-type-$index',
                  value: normaliseRoutineType(draft.type),
                  onChanged: onTypeChanged,
                ),
              ),
              IconButton(
                tooltip: l.progDeleteExercise,
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.subtleForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: ValueKey<String>('program-name-$index'),
            controller: draft.name,
            decoration: InputDecoration(
              labelText: l.progExerciseName,
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              // "횟수/시간"("Reps/time")이 세 라벨 중 가장 길다 — 셋을
              // 똑같이 나누면 그 라벨만 잘린다. 라벨 글씨를 살짝 줄이고
              // 그 칸에 몫을 더 준다.
              Expanded(
                flex: 3,
                child: TextField(
                  key: ValueKey<String>('program-sets-$index'),
                  controller: draft.sets,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.progSets,
                    labelStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 4,
                child: TextField(
                  key: ValueKey<String>('program-reps-$index'),
                  controller: draft.reps,
                  decoration: InputDecoration(
                    labelText: l.progReps,
                    labelStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: TextField(
                  key: ValueKey<String>('program-weight-$index'),
                  controller: draft.weight,
                  decoration: InputDecoration(
                    labelText: l.progWeight,
                    hintText: l.progOptional,
                    labelStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          RoutineMinutesSlider(
            key: ValueKey<String>('program-duration-$index'),
            minutes: storedDuration != null
                ? storedDuration.clamp(5, 120)
                : 5,
            onChanged: onDurationChanged,
          ),
        ],
      ),
    );
  }
}
