import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 세션 하나에 할 수 있는 일들. (#871, #1011, #1012)
///
/// 일곱 개가 같은 크기·같은 모양으로 늘어서 있었다. 버튼이 많아 보이는 것이
/// 아니라 실제로 많았고, 되돌릴 수 없는 `삭제` 가 자주 쓰는 `채팅` 과 나란히
/// 서 있었다.
///
/// 지금은 두 가지로 정리한다.
///
///  * **갈래로 묶는다.** "이 약속이 어떻게 끝났나"(완료·취소·노쇼) / "일정을
///    손본다"(수정·삭제) / "고객에게 간다"(채팅) 를 구분선으로 가른다.
///  * **자주 쓰는 것만 글씨로 남긴다.** 매 세션마다 누르는 `완료`·`채팅` 은
///    글씨를 지키고, 나머지는 아이콘으로 줄인다. 아이콘만으로는 무엇인지 말하지
///    못하므로 툴팁과 시맨틱 라벨을 반드시 함께 단다.
///
/// `삭제` 는 마지막 자리에 채우지 않은 알약으로 둔다. 되돌릴 수 없는 동작을
/// 다른 것들과 같은 무게로 세우지 않는다.
class SessionManageRow extends StatelessWidget {
  const SessionManageRow({
    super.key,
    required this.onEditSchedule,
    required this.onEditProgram,
    required this.onEditNote,
    required this.hasProgram,
    required this.onDelete,
    required this.onChat,
    required this.onComplete,
    this.onCancel,
    this.onNoShow,
  });

  final VoidCallback onEditSchedule;
  final VoidCallback onEditProgram;

  /// 운동 목록 없이 메모만 여는 자리. 세션 종류와 상관없이 있다(#1011).
  final VoidCallback onEditNote;

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
    final ended = <Widget>[
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
      if (onCancel != null)
        _ActionChip(
          key: const ValueKey<String>('session-cancel-chip'),
          icon: Icons.event_busy_outlined,
          label: l.schedCancel,
          color: AppColors.warning,
          iconOnly: true,
          onTap: onCancel!,
        ),
      if (onNoShow != null)
        _ActionChip(
          key: const ValueKey<String>('session-no-show-chip'),
          icon: Icons.person_off_outlined,
          label: l.schedNoShow,
          color: AppColors.warning,
          iconOnly: true,
          onTap: onNoShow!,
        ),
    ];

    final edits = <Widget>[
      _ActionChip(
        key: const ValueKey<String>('session-edit-schedule-chip'),
        icon: Icons.edit_calendar_outlined,
        label: l.schedEditTitle,
        color: AppColors.accent,
        iconOnly: true,
        onTap: onEditSchedule,
      ),
      if (hasProgram)
        _ActionChip(
          key: const ValueKey<String>('session-edit-program-chip'),
          icon: Icons.fitness_center,
          label: l.progEditTitle,
          color: AppColors.secondary,
          iconOnly: true,
          onTap: onEditProgram,
        ),
      _ActionChip(
        key: const ValueKey<String>('session-edit-note-chip'),
        icon: Icons.edit_note,
        label: l.schedEditNote,
        // 메모지의 색이다. `SessionNoteBox` 와 같은 주황을 써야 두 자리가 같은
        // 것을 가리킨다 — 주의(빨강)가 아니라 적어 두는 자리다(#690, #1012).
        color: AppColors.brandOrange,
        iconOnly: true,
        onTap: onEditNote,
      ),
    ];

    // 갈래를 띄울 거라면 끝까지 띄운다 — `채팅`·`삭제` 는 오른쪽 끝에 붙여
    // 세션을 손보는 동작들과 확실히 갈라 놓는다(#1012).
    return Row(
      children: <Widget>[
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ...ended,
              if (ended.isNotEmpty) const _GroupDivider(),
              ...edits,
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ActionChip(
          key: const ValueKey<String>('session-chat-chip'),
          icon: Icons.chat_bubble_outline,
          label: l.clientChat,
          color: AppColors.accent,
          onTap: onChat,
        ),
        const SizedBox(width: AppSpacing.xs),
        // 되돌릴 수 없는 동작이라 마지막 자리에, 채우지 않은 알약으로 둔다.
        _ActionChip(
          key: const ValueKey<String>('session-delete-chip'),
          icon: Icons.delete_outline,
          label: l.actionDelete,
          color: AppColors.destructive,
          iconOnly: true,
          quiet: true,
          onTap: onDelete,
        ),
      ],
    );
  }
}

/// 갈래 사이의 얇은 세로 선. 간격만으로는 묶음이 보이지 않는다.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      color: AppColors.border,
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconOnly = false,
    this.quiet = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  /// A real icon rather than a '✓'/'💬' typed into the label: those depend on
  /// whatever fallback font the platform loads and render as 두부 boxes on
  /// Flutter web.
  final IconData icon;

  /// 글씨 없이 아이콘만 그린다. 그래도 [label] 은 툴팁과 시맨틱스로 남는다 —
  /// 아이콘만으로는 무엇인지 말하지 못한다.
  final bool iconOnly;

  /// 채우지 않는다. 되돌릴 수 없는 동작을 자주 쓰는 것들과 같은 무게로 세우지
  /// 않기 위해서다.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final Widget content = iconOnly
        ? Icon(icon, size: 15, color: color)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          );

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: quiet ? Colors.transparent : color.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(AppRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.pill),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: iconOnly ? AppSpacing.sm : AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: quiet
                  ? BoxDecoration(
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    )
                  : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
