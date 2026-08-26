import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 프로그램 한 줄 — 운동 이름과, 유형에 맞는 값.
///
/// 근력은 세트·중량으로, 나머지는 시간으로 읽는다 (#1276) — 유형마다 재는 단위가
/// 다르다.
class SessionProgramRow extends StatelessWidget {
  const SessionProgramRow({super.key, required this.index, required this.item});

  final int index;
  final ProgramItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<String> parts = <String>[
      if (item.type == '근력') ...<String>[
        if (item.sets != null) l.progSetsValue(item.sets!),
        if (item.reps != null && item.reps! > 0) l.progRepsValue(item.reps!),
        // 맨몸 운동은 `0kg` 이다 — 중량 칸은 비울 수 없고(최솟값 0) 근력을
        // 고르면 언제나 값을 하나 든다. 값이 아예 없는 것은 이 규칙이 서기
        // 전에 저장된 행뿐이라, 그때만 자리를 비운다.
        if (item.weight != null)
          '${_trimZero(item.weight!)}${l.routineUnitKg}',
      ] else if (item.duration != null)
        l.minutesShort(item.duration!),
    ];
    final String detail = parts.join(' · ');
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
                if (detail.isNotEmpty)
                  Text(
                    detail,
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

/// 40.0 → "40", 40.5 → "40.5". 소수점 뒤 0 은 적지 않는다.
String _trimZero(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : '$v';

/// Shown inside an expanded 예정 session that has no program yet.
///
/// 상담의 [SessionNoNoteBox]처럼, 바로가기를 이 상자 안에 둔다 — 예전에는 이
/// 안내와 그 동작이 서로 떨어져 있었다. 다만 메모와 달리 프로그램은 **이
/// 카드 안에서 짓지 않는다** — AI 코칭 탭에서 만들어 보내는 것이라, 이 아이콘은
/// 편집기를 여는 대신 그 고객의 코칭 탭으로 이동한다(#1247). 관리 줄 쪽
/// `프로그램 수정` 아이콘은 프로그램이 비어 있는 동안은 [SessionManageRow]가
/// 숨긴다.
class SessionNoPlanBox extends StatelessWidget {
  const SessionNoPlanBox({super.key, required this.onGoToProgram});

  /// 코칭 탭의 그 고객 프로그램 화면으로 이동한다.
  final VoidCallback onGoToProgram;

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
          // `프로그램 수정`(관리 줄, `session-edit-program-chip`)과는 다른
          // 동작이라 키도 다르다 — 이 카드에서 편집기를 여는 게 아니라 코칭
          // 탭으로 나간다.
          _ProgramAddChip(
            key: const ValueKey<String>('session-add-program-chip'),
            label: l.progAddTitle,
            onTap: onGoToProgram,
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
