import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 수정 · 삭제 · 채팅 바로가기 actions for a booked session.
class SessionManageRow extends StatelessWidget {
  const SessionManageRow({
    super.key,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
  });

  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;
  final VoidCallback onDelete;
  final VoidCallback onChat;
  final VoidCallback? onComplete;

  /// 예정 세션만 — 진행되지 않은 약속을 `취소` 기록으로 남긴다(#871).
  final VoidCallback? onCancel;

  /// 예정이면서 지나간 세션만 — 회원이 오지 않았다는 기록.
  final VoidCallback? onNoShow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        if (onComplete != null)
          _ActionChip(
            // Keyed: l.legendDone is also a status word elsewhere on this row,
            // so text alone no longer identifies the action.
            key: const ValueKey<String>('session-complete-chip'),
            icon: Icons.check,
            label: l.legendDone,
            color: AppColors.success,
            onTap: onComplete!,
          ),
        // 취소·노쇼는 완료 옆이다 — 셋 다 "이 약속이 어떻게 끝났나" 를 적는
        // 동작이고, 수정·삭제는 일정 자체를 손보는 다른 갈래다(#871).
        if (onCancel != null)
          _ActionChip(
            key: const ValueKey<String>('session-cancel-chip'),
            icon: Icons.event_busy_outlined,
            label: l.schedCancel,
            color: AppColors.warning,
            onTap: onCancel!,
          ),
        if (onNoShow != null)
          _ActionChip(
            key: const ValueKey<String>('session-no-show-chip'),
            icon: Icons.person_off_outlined,
            label: l.schedNoShow,
            color: AppColors.warning,
            onTap: onNoShow!,
          ),
        _ActionChip(
          label: l.schedEditTitle,
          color: AppColors.accent,
          onTap: onEditSchedule,
        ),
        _ActionChip(
          label: l.progEditTitle,
          color: AppColors.secondary,
          onTap: onEditProgram,
        ),
        _ActionChip(
          label: l.actionDelete,
          color: AppColors.destructive,
          onTap: onDelete,
        ),
        _ActionChip(
          key: const ValueKey<String>('session-chat-chip'),
          icon: Icons.chat_bubble_outline,
          label: l.clientChat,
          color: AppColors.accent,
          onTap: onChat,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Drawn ahead of [label]. A real icon rather than a '✓'/'💬' typed into
  /// the label: those depend on whatever fallback font the platform loads
  /// and render as 두부 boxes on Flutter web.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: icon == null
              ? text
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 3),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}
