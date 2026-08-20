import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

/// 완료 처리 확인 다이얼로그 — owns the memo controller so it outlives
/// the route's exit transition (disposing it in the caller races the
/// dialog teardown).
class CompleteSessionDialog extends StatefulWidget {
  const CompleteSessionDialog({super.key, required this.session});

  final ScheduleSession session;

  @override
  State<CompleteSessionDialog> createState() => _CompleteSessionDialogState();
}

class _CompleteSessionDialogState extends State<CompleteSessionDialog> {
  final TextEditingController _memo = TextEditingController();

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final s = widget.session;
    return AlertDialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      title: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
            child: const Icon(
              Icons.task_alt,
              color: AppColors.success,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(l.schedCompleteTitle, style: const TextStyle(fontSize: 17)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.schedCompleteBody(s.time, s.clientName),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _memo,
              decoration: InputDecoration(
                hintText: l.schedNoteOptional,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        ActionButton(
          label: l.actionCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ActionButton(
          label: l.schedCompleteAction,
          primary: true,
          onPressed: () => Navigator.of(context).pop(_memo.text.trim()),
        ),
      ],
    );
  }
}
