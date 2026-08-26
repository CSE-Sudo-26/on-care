import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// `일정 추가` 를 누르기 전 한 번 더 확인한다(#1029) — 이 버튼 하나가
/// 배정과 PT 일정 등록을 함께 하므로, 어느 날짜·시각으로 스케줄에
/// 올라가는지 미리 말해야 한다. `showRoutineSuggestionConfirmDialog` 와
/// 같은 모양을 쓴다.
Future<bool?> showProgramAssignConfirmDialog(
  BuildContext context, {
  required String clientName,
  required DateTime registerDate,
  required TimeOfDay registerStartTime,
  required TimeOfDay registerEndTime,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final AppLocalizations l = AppLocalizations.of(dialogContext);
      return AlertDialog(
        key: const ValueKey<String>('program-assign-confirm'),
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
        title: Text(
          l.programAssignConfirmTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 360,
          child: Text(
            l.programAssignConfirmBody(
              clientName,
              ymd(registerDate),
              '${registerStartTime.format(dialogContext)} – '
              '${registerEndTime.format(dialogContext)}',
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
              height: 1.4,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('program-assign-confirm-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('program-assign-confirm-submit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.programEditorAddSchedule),
          ),
        ],
      );
    },
  );
}
