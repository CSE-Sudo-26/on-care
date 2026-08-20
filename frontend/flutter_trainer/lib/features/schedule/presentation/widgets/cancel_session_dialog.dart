import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

/// 취소 확인 — 주체를 고르고 (선택) 사유를 남긴다. (#871)
///
/// 주체에 기본값을 두지 않는다. 무엇이든 기본으로 저장되면 그 값이 사실인지 알
/// 수 없고, 나중에 "고객 취소가 몇 건이었나" 를 읽을 때 그대로 거짓이 된다.
class CancelSessionDialog extends StatefulWidget {
  const CancelSessionDialog({super.key, required this.session});

  final ScheduleSession session;

  @override
  State<CancelSessionDialog> createState() => _CancelSessionDialogState();
}

class _CancelSessionDialogState extends State<CancelSessionDialog> {
  final TextEditingController _reason = TextEditingController();
  String? _source;

  @override
  void dispose() {
    _reason.dispose();
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
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              color: AppColors.warning,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.schedCancelTitle,
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.schedCancelConfirm(s.time, s.clientName),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.schedCancelSource,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.subtleForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final source in CancellationSource.all)
                  ChoiceChip(
                    key: ValueKey<String>('cancel-source-$source'),
                    label: Text(cancellationSourceLabel(l, source)),
                    selected: _source == source,
                    onSelected: (_) => setState(() => _source = source),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('cancel-reason-input'),
              controller: _reason,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: l.schedCancelReasonHint,
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
          key: const ValueKey<String>('session-cancel-confirm'),
          label: l.schedCancel,
          primary: true,
          tone: AppColors.warning,
          // 주체를 고르기 전에는 저장할 수 없다 — 기본값으로 채우면 그 값이
          // 사실인지 알 수 없다.
          onPressed: _source == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((source: _source!, reason: _reason.text.trim())),
        ),
      ],
    );
  }
}
