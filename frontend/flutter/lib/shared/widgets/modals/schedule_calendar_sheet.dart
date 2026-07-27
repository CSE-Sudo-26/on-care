import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:oncare/features/schedule/presentation/schedule_category_color.dart';
import 'package:oncare/shared/widgets/modals/add_event_dialog.dart';

String _monthKey(DateTime m) =>
    '${m.year}-${m.month.toString().padLeft(2, '0')}';

/// Bottom sheet showing a month calendar backed by real schedule events
/// (`GET /schedule/events?month=…`). Events are colored by category so the
/// same category always reads the same color.
Future<void> showScheduleCalendarSheet(
  BuildContext context, {
  DateTime? initialDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.card),
    ),
    builder: (BuildContext ctx) => ConstrainedBox(
      // Match the main content width so the sheet scales with the viewport
      // like the tab pages. The theme lifts the modal route cap to this
      // width too (see AppTheme._bottomSheetTheme); this centres the child.
      constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
      child: _CalendarBody(initialDate: initialDate ?? DateTime.now()),
    ),
  );
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.initialDate});
  final DateTime initialDate;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  late DateTime _month = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  static const List<String> _weekdays = <String>[
    '일',
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
  ];

  Map<int, List<ScheduleEvent>> _groupByDay(List<ScheduleEvent> events) {
    final map = <int, List<ScheduleEvent>>{};
    for (final ScheduleEvent e in events) {
      final day = int.tryParse(e.date.split('-').last);
      if (day == null) continue;
      (map[day] ??= <ScheduleEvent>[]).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthKey = _monthKey(_month);
    final async = ref.watch(scheduleMonthProvider(monthKey));
    final today = DateTime.now();
    final days = _daysInGrid(_month);

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '일정 관리',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _CircleClose(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                ),
                Text(
                  '${_month.year}년 ${_month.month}월',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    await showAddEventDialog(context);
                    // 추가된 일정이 이 달 그리드에 반영되도록 새로고침.
                    ref.invalidate(scheduleMonthProvider(monthKey));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(AppRadius.md),
                    ),
                  ),
                  child: const Text('일정 추가'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const _CategoryLegend(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                for (final String w in _weekdays)
                  Expanded(
                    child: Container(
                      color: AppColors.accent,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        w,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: async.when(
                skipLoadingOnRefresh: true,
                data: (List<ScheduleEvent> events) {
                  final byDay = _groupByDay(events);
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: days.length,
                    itemBuilder: (BuildContext _, int i) {
                      final day = days[i];
                      if (day == null) {
                        return const DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.border),
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                        );
                      }
                      final isToday =
                          day.year == today.year &&
                          day.month == today.month &&
                          day.day == today.day;
                      final dayEvents =
                          byDay[day.day] ?? const <ScheduleEvent>[];
                      return Container(
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : null,
                          border: const Border(
                            right: BorderSide(color: AppColors.border),
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${day.day}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isToday ? AppColors.primary : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            for (final ScheduleEvent e in dayEvents)
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheduleCategoryColor(e.category),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${e.time} ${e.title}'.trim(),
                                  style: const TextStyle(fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(
                  child: Text(
                    '일정을 불러오지 못했어요',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  static List<DateTime?> _daysInGrid(DateTime month) {
    final first = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leading = first.weekday % 7; // Sunday-first
    return <DateTime?>[
      for (int i = 0; i < leading; i++) null,
      for (int d = 1; d <= lastDay.day; d++)
        DateTime(month.year, month.month, d),
    ];
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 4,
      children: <Widget>[
        for (final ScheduleCategory c in ScheduleCategory.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheduleCategoryColor(c),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                scheduleCategoryLabel(c),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CircleClose extends StatelessWidget {
  const _CircleClose({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.close, size: 18),
        ),
      ),
    );
  }
}
