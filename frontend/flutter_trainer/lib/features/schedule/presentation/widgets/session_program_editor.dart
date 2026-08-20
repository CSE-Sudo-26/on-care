import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
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
      if (name.isEmpty || sets == null || sets < 1 || sets > 100) {
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
            note: _note.text.trim(),
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
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              onPressed: _saving ? null : _addItem,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.progAddExercise),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
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
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: Text(l.actionCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('save-program'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? l.progSaving : l.progSaveAction),
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
  });

  final int index;
  final ProgramDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-name-$index'),
                  controller: draft.name,
                  decoration: InputDecoration(
                    labelText: l.progExerciseName,
                    isDense: true,
                  ),
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
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-sets-$index'),
                  controller: draft.sets,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.progSets,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-reps-$index'),
                  controller: draft.reps,
                  decoration: InputDecoration(
                    labelText: l.progReps,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: ValueKey<String>('program-weight-$index'),
                  controller: draft.weight,
                  decoration: InputDecoration(
                    labelText: l.progWeight,
                    hintText: l.progOptional,
                    isDense: true,
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
