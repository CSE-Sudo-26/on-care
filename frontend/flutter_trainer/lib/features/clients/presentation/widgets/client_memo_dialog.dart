import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/trainer_memo.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/trainer_memo_repository.dart';

/// Opens the per-member memo list for [clientId].
///
/// The same list backs the chat-insight "메모에 추가" action, so a memo saved
/// from a conversation appears here next to the ones written by hand.
Future<void> showClientMemoDialog(
  BuildContext context, {
  required String clientId,
  required String clientName,
}) => showDialog<void>(
  context: context,
  builder: (_) => ClientMemoDialog(clientId: clientId, clientName: clientName),
);

/// Lists, writes and edits the memos a trainer keeps about one member (#706).
class ClientMemoDialog extends ConsumerStatefulWidget {
  const ClientMemoDialog({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  final String clientId;
  final String clientName;

  @override
  ConsumerState<ClientMemoDialog> createState() => _ClientMemoDialogState();
}

class _ClientMemoDialogState extends ConsumerState<ClientMemoDialog> {
  /// Mirrors the backend's `TrainerMemoCreateRequest.body` cap so an
  /// over-long memo is rejected here instead of round-tripping for a 422.
  static const int _maxLength = 2000;

  final TextEditingController _draft = TextEditingController();

  /// A write is in flight. Every action reads this before firing so a
  /// double click can't create the same memo twice, and so the list is
  /// never mutated from two directions at once.
  bool _busy = false;

  /// Memo being edited, or null while writing a new one. Editing is kept in
  /// this dialog's state (not in the row widgets) so a rebuild from the
  /// provider — after a save elsewhere — can't strand a half-typed row.
  String? _editingId;
  final TextEditingController _edit = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    _edit.dispose();
    super.dispose();
  }

  /// Runs [write], then reloads the list. On failure the list is left
  /// untouched and the draft text stays in the field so the trainer can
  /// retry without retyping.
  Future<void> _run(Future<void> Function() write, String fallback) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await write();
      ref.invalidate(trainerMemosProvider(widget.clientId));
      if (!mounted) return;
      setState(() => _busy = false);
    } on AppError catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(serverDetailOr(AppLocalizations.of(context), error.message, fallback));
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(fallback);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final body = _draft.text.trim();
    if (body.isEmpty) return;
    final l = AppLocalizations.of(context);
    await _run(() async {
      await ref
          .read(trainerMemoRepositoryProvider)
          .create(widget.clientId, body: body);
      _draft.clear();
    }, l.clientTrainerMemoSaveFailed);
  }

  Future<void> _saveEdit(TrainerMemo memo) async {
    final body = _edit.text.trim();
    if (body.isEmpty) return;
    if (body == memo.body) {
      setState(() => _editingId = null);
      return;
    }
    final l = AppLocalizations.of(context);
    await _run(() async {
      await ref
          .read(trainerMemoRepositoryProvider)
          .update(widget.clientId, memo.id, body);
      _editingId = null;
    }, l.clientTrainerMemoSaveFailed);
  }

  Future<void> _delete(TrainerMemo memo) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.clientTrainerMemoDeleteTitle),
        content: Text(l.clientTrainerMemoDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await ref
          .read(trainerMemoRepositoryProvider)
          .delete(widget.clientId, memo.id);
      if (_editingId == memo.id) _editingId = null;
    }, l.clientTrainerMemoDeleteFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final memos = ref.watch(trainerMemosProvider(widget.clientId));

    return AlertDialog(
      title: Text(l.clientTrainerMemoTitle(widget.clientName)),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('client-memo-input'),
              controller: _draft,
              maxLines: 3,
              maxLength: _maxLength,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: l.clientTrainerMemoHint,
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey<String>('client-memo-add'),
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l.clientTrainerMemoAdd),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Flexible, not a fixed max height: the dialog is also opened on
            // a short window, where a hard 320px list would push the actions
            // off the bottom.
            Flexible(
              child: memos.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _LoadFailed(
                  message: error is AppError
                      ? serverDetailOr(
                          l,
                          error.message,
                          l.clientTrainerMemoLoadFailed,
                        )
                      : l.clientTrainerMemoLoadFailed,
                  onRetry: () =>
                      ref.invalidate(trainerMemosProvider(widget.clientId)),
                ),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Text(
                          l.clientTrainerMemoEmpty,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, index) => _memoTile(l, list[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
    );
  }

  Widget _memoTile(AppLocalizations l, TrainerMemo memo) {
    final editing = _editingId == memo.id;
    return Container(
      key: ValueKey<String>('client-memo-${memo.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: const BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (memo.source == TrainerMemoSource.chatInsight)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l.clientTrainerMemoFromChat,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          if (editing)
            TextField(
              key: ValueKey<String>('client-memo-edit-${memo.id}'),
              controller: _edit,
              maxLines: 3,
              maxLength: _maxLength,
              enabled: !_busy,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            )
          else
            Text(memo.body),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _dayLabel(memo.updatedAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              if (editing) ...<Widget>[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _editingId = null),
                  child: Text(l.actionCancel),
                ),
                TextButton(
                  key: ValueKey<String>('client-memo-save-${memo.id}'),
                  onPressed: _busy ? null : () => _saveEdit(memo),
                  child: Text(l.actionSave),
                ),
              ] else ...<Widget>[
                TextButton(
                  key: ValueKey<String>('client-memo-edit-open-${memo.id}'),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _editingId = memo.id;
                          _edit.text = memo.body;
                        }),
                  child: Text(l.actionEdit),
                ),
                TextButton(
                  key: ValueKey<String>('client-memo-delete-${memo.id}'),
                  onPressed: _busy ? null : () => _delete(memo),
                  child: Text(l.actionDelete),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime at) {
    final local = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const ValueKey<String>('client-memo-retry'),
            onPressed: onRetry,
            child: Text(l.actionRetry),
          ),
        ],
      ),
    );
  }
}
