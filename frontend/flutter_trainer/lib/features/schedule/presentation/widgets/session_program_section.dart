import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 프로그램 한 줄 — 운동 이름과 세트·횟수·무게.
class SessionProgramRow extends StatelessWidget {
  const SessionProgramRow({super.key, required this.index, required this.item});

  final int index;
  final ProgramItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final detail = StringBuffer(l.progSetsByReps(item.sets, item.reps));
    if (item.weight != '-') detail.write(' · ${item.weight}');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(AppRadius.sm),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  detail.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.subtleForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown inside an expanded 예정 session that has no program yet.
///
/// 상담의 [SessionNoNoteBox]처럼, 프로그램 화면으로 가는 바로가기를 이 상자
/// 안에 둔다 — 예전에는 이 안내와 그 동작(관리 줄의 `프로그램 수정`)이 서로
/// 떨어져 있었다. 관리 줄 쪽 아이콘은 프로그램이 비어 있는 동안은
/// [SessionManageRow]가 숨긴다(#1236).
class SessionNoPlanBox extends StatelessWidget {
  const SessionNoPlanBox({super.key, required this.onAdd});

  /// 프로그램을 처음 짜는 자리를 연다.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('session-no-plan'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.progEmpty,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.progEmptyHint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.subtleForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 키는 `session_manage_row.dart`의 `_ActionChip`과 같은 값을 쓴다 —
          // 프로그램이 비어 있으면 그 아이콘이 관리 줄 대신 여기 선다.
          _ProgramAddChip(
            key: const ValueKey<String>('session-edit-program-chip'),
            label: l.progEditTitle,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ProgramAddChip extends StatelessWidget {
  const _ProgramAddChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(AppRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.pill),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                Icons.fitness_center,
                size: 15,
                color: AppColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
