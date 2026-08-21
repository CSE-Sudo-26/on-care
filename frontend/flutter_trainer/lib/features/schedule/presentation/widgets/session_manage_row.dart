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
    required this.onEditNote,
    required this.hasNote,
    required this.hasProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
  });

  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;

  /// 운동 목록 없이 메모만 여는 자리. (#1011)
  ///
  /// 세션 종류와 상관없이 늘 있다. 메모가 `프로그램 수정` 안쪽, 운동 목록을 다
  /// 지나야 나오는 자리에만 있던 때에는 1:1 PT 의 메모를 남기려면 프로그램
  /// 편집기를 열고 스크롤해 내려가야 했다 — 매주 반복되는 세션에서 가장 자주
  /// 손대는 값인데도.
  final VoidCallback onEditNote;

  /// 이미 남긴 메모가 있는가. (#1011)
  ///
  /// 자리는 하나지만 **하는 일이 둘**이다 — 빈 세션에서는 처음 적는 것이고,
  /// 적어 둔 세션에서는 고치는 것이다. 아무것도 적지 않았는데 `메모 수정` 이라고
  /// 부르면, 어딘가에 이미 메모가 있는데 못 찾고 있는 것처럼 읽힌다. 글자와
  /// 아이콘이 함께 갈린다 — `메모 추가`(＋)와 `메모 수정`(연필).
  final bool hasNote;

  /// 프로그램을 짜는 세션인가. 상담은 아니므로 `프로그램 수정` 이 서지 않는다 —
  /// 누를 이유가 없는 버튼으로 읽힌다(#988).
  final bool hasProgram;

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
        if (hasProgram)
          _ActionChip(
            key: const ValueKey<String>('session-edit-program-chip'),
            label: l.progEditTitle,
            color: AppColors.secondary,
            onTap: onEditProgram,
          ),
        _ActionChip(
          key: const ValueKey<String>('session-edit-note-chip'),
          label: hasNote ? l.schedEditNote : l.schedAddNote,
          color: AppColors.secondary,
          onTap: onEditNote,
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
