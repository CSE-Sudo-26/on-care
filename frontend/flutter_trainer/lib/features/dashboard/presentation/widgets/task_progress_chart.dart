import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/data/daily_task_progress_store.dart';

/// 월~일 stacked bar of daily 오늘 할 일 completion.
///
/// Each bar has two segments: that day's own tasks (navy) stacked under
/// tasks that were **carried over** from an earlier day's unfinished list
/// (회색이 섞인 푸른색) — [DailyTaskSnapshot.completedCarriedOver] is a real
/// count, not a visual flourish, so a taller band means the trainer is
/// clearing a real backlog that day.
class TaskProgressChart extends StatelessWidget {
  /// Creates the chart.
  const TaskProgressChart({
    super.key,
    required this.snapshots,
    required this.dates,
    required this.labels,
    required this.todayIndex,
    this.isCurrentWeek = true,
  });

  /// One entry per weekday (월→일), or null when nothing was saved that day.
  final List<DailyTaskSnapshot?> snapshots;

  /// Calendar date for each column, same length as [snapshots] — combined
  /// with [labels] into `8/23 일` so a past week reads as *which* past
  /// week, not just "월~일" again.
  final List<DateTime> dates;

  /// Weekday labels, same length as [snapshots].
  final List<String> labels;

  /// Index of today in [snapshots] — later indices haven't happened yet.
  final int todayIndex;

  /// Whether [dates] is the week containing today. A past week has no
  /// "today" to bold and no day left to greyed out as not-yet-happened.
  final bool isCurrentWeek;

  /// "그날 목록의 몇 %를 처리했나" — 이월까지 포함한 완료 수를 그날 전체
  /// 목록(오늘치 + 이월) 기준으로 잰다. 아직 오지 않았거나 기록이 없는
  /// 날은 숫자를 보여줄 근거가 없어 빈 칸이다.
  static String _percentLabel(DailyTaskSnapshot? snapshot) {
    if (snapshot == null || snapshot.total == 0) return '';
    final percent = (snapshot.completed / snapshot.total * 100).round();
    return '$percent%';
  }

  @override
  Widget build(BuildContext context) {
    final ceiling = <int>[
      1,
      for (final s in snapshots)
        if (s != null) s.total,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 102,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < snapshots.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _StackedBar(
                      index: i,
                      snapshot: snapshots[i],
                      percentLabel: _percentLabel(snapshots[i]),
                      ceiling: ceiling,
                      pending: isCurrentWeek && i > todayIndex,
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
                  // "8/23 일" — 지난 주로 넘어가도 어느 요일이 아니라 어느
                  // *날* 인지 읽혀야 한다.
                  '${dates[i].month}/${dates[i].day} ${labels[i]}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isCurrentWeek && i == todayIndex
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: isCurrentWeek && i == todayIndex
                        ? AppColors.primary
                        : isCurrentWeek && i > todayIndex
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

/// A colour-dot + label legend entry — used both by the chart's own header
/// (previously) and now by [_TaskProgressCard]'s section header, next to
/// the card title.
class TaskProgressLegend extends StatelessWidget {
  /// Creates one legend entry.
  const TaskProgressLegend({
    super.key,
    required this.color,
    required this.label,
  });

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
    required this.index,
    required this.snapshot,
    required this.percentLabel,
    required this.ceiling,
    required this.pending,
  });

  final int index;
  final DailyTaskSnapshot? snapshot;
  final String percentLabel;
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
        const labelHeight = 12.0;
        const labelGap = 2.0;
        final maxBarHeight = constraints.maxHeight - labelHeight - labelGap;
        final todayHeight = maxBarHeight * (s.completedToday / ceiling);
        final carriedHeight = maxBarHeight * (s.completedCarriedOver / ceiling);
        final totalHeight = (todayHeight + carriedHeight).clamp(
          s.completed > 0 ? 2.0 : 0.0,
          maxBarHeight,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Text(
                  percentLabel,
                  key: ValueKey<String>('task-progress-percent-$index'),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.subtleForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: labelGap),
            SizedBox(
              key: ValueKey<String>('task-progress-bar-$index'),
              height: totalHeight,
              child: Column(
                children: <Widget>[
                  if (carriedHeight > 0)
                    Container(
                      height: carriedHeight,
                      decoration: const BoxDecoration(
                        color: AppColors.aiCardGradientEnd,
                        borderRadius: BorderRadius.vertical(top: AppRadius.xs),
                      ),
                    ),
                  if (todayHeight > 0)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: carriedHeight > 0
                              ? null
                              : const BorderRadius.vertical(top: AppRadius.xs),
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
