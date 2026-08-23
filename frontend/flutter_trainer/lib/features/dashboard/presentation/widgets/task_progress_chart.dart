import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/data/daily_task_progress_store.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 월~일 stacked bar of daily 오늘 할 일 completion.
///
/// Each bar has two segments: that day's own tasks (navy) stacked under
/// tasks that were **carried over** from an earlier day's unfinished list
/// (주황) — [DailyTaskSnapshot.completedCarriedOver] is a real count, not a
/// visual flourish, so a taller orange band means the trainer is clearing a
/// real backlog that day.
class TaskProgressChart extends StatelessWidget {
  /// Creates the chart.
  const TaskProgressChart({
    super.key,
    required this.snapshots,
    required this.labels,
    required this.todayIndex,
  });

  /// One entry per weekday (월→일), or null when nothing was saved that day.
  final List<DailyTaskSnapshot?> snapshots;

  /// Weekday labels, same length as [snapshots].
  final List<String> labels;

  /// Index of today in [snapshots] — later indices haven't happened yet.
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ceiling = <int>[
      1,
      for (final s in snapshots)
        if (s != null) s.total,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // `Wrap`, not `Row` — 영어 로케일의 "Done (carried over)" 는 좁은
        // 카드 폭에서 `Row` 로는 넘친다(#[dashboard]).
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: 4,
          children: <Widget>[
            _Legend(color: AppColors.primary, label: l.dashTaskProgressToday),
            _Legend(
              color: AppColors.statusCaution,
              label: l.dashTaskProgressCarriedOver,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < snapshots.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _StackedBar(
                      snapshot: snapshots[i],
                      ceiling: ceiling,
                      pending: i > todayIndex,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == todayIndex
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i == todayIndex
                        ? AppColors.primary
                        : i > todayIndex
                        ? AppColors.disabledForeground
                        : AppColors.subtleForeground,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
      ],
    );
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.snapshot,
    required this.ceiling,
    required this.pending,
  });

  final DailyTaskSnapshot? snapshot;
  final int ceiling;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    // 아직 오지 않은 요일과, 그날 대시보드를 아예 열지 않아 기록이 없는
    // 요일은 같은 빈 트랙이지만 다른 사실이다 — 어느 쪽도 `0` 으로 읽히면
    // 안 된다.
    final missing = !pending && snapshot == null;
    if (pending || missing) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.vertical(top: AppRadius.xs),
        ),
        child: SizedBox(height: 2),
      );
    }

    final s = snapshot!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final todayHeight = maxHeight * (s.completedToday / ceiling);
        final carriedHeight = maxHeight * (s.completedCarriedOver / ceiling);
        final totalHeight = (todayHeight + carriedHeight).clamp(
          s.completed > 0 ? 2.0 : 0.0,
          maxHeight,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            SizedBox(
              height: totalHeight,
              child: Column(
                children: <Widget>[
                  if (carriedHeight > 0)
                    Container(
                      height: carriedHeight,
                      decoration: const BoxDecoration(
                        color: AppColors.statusCaution,
                        borderRadius: BorderRadius.vertical(
                          top: AppRadius.xs,
                        ),
                      ),
                    ),
                  if (todayHeight > 0)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: carriedHeight > 0
                              ? null
                              : const BorderRadius.vertical(
                                  top: AppRadius.xs,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
