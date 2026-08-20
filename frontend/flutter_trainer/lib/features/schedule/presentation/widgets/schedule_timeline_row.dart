import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// One timeline row: the time gutter + a session card or a gap slot.
class ScheduleTimelineRow extends StatelessWidget {
  const ScheduleTimelineRow({
    super.key,
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
    required this.programDateLabel,
    required this.sendingProgram,
    required this.onSendProgram,
    required this.inlineEditor,
  });

  final ScheduleSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  /// 예정 세션의 `취소`·`노쇼` 기록 처리. 대상이 아니면 null 이라 화면에 나오지
  /// 않는다 — 서버가 409 로 막을 동작을 아예 내놓지 않는다(#871).
  final VoidCallback? onCancel;
  final VoidCallback? onNoShow;
  final String programDateLabel;

  /// 이 세션의 프로그램 전송이 진행 중인가. (#822)
  final bool sendingProgram;

  /// 완료한 세션의 프로그램을 회원에게 보낸다.
  final VoidCallback onSendProgram;
  final Widget? inlineEditor;

  /// 예정 sessions only — flips to 완료 and logs the 운동기록.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              session.time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: session.isDone
                    ? AppColors.disabledForeground
                    : AppColors.foreground,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: session.isGap
              ? const _GapSlot()
              : SessionCard(
                  key: ValueKey<String>('schedule-session-${session.id}'),
                  session: session,
                  expanded: expanded,
                  onToggle: onToggle,
                  onEditSchedule: onEditSchedule,
                  onEditProgram: onEditProgram,
                  onDelete: onDelete,
                  onCancel: onCancel,
                  onNoShow: onNoShow,
                  onChat: onChat,
                  onComplete: onComplete,
                  programDateLabel: programDateLabel,
                  sendingProgram: sendingProgram,
                  onSendProgram: onSendProgram,
                  inlineEditor: inlineEditor,
                ),
        ),
      ],
    );
  }
}

class _GapSlot extends StatelessWidget {
  const _GapSlot();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        l.dashEmptySlot,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.subtleForeground,
        ),
      ),
    );
  }
}
