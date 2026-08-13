import 'dart:math' as math;

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
      constraints: const BoxConstraints(
        maxWidth: AppBreakpoints.contentMaxWidth,
      ),
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

  /// 한 주 칸의 최소 높이. 남은 높이를 주 수로 나눈 값이 이보다 작아지면 —
  /// 세로가 짧은 기기나 6주짜리 달 — 칸을 더 줄이는 대신 그리드를 스크롤한다.
  /// 날짜 숫자와 일정 칩 한 줄이 들어가는 최소치다.
  static const double _minRowHeight = 56;

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
                  return LayoutBuilder(
                    builder: (BuildContext _, BoxConstraints constraints) {
                      // 칸 높이를 남은 세로 공간에서 정한다. 가로폭에서 고정
                      // 비율로 잡으면 6주짜리 달의 마지막 주가 남은 높이를
                      // 넘겨 잘렸다 — 스크롤도 꺼져 있어 8월이 22일에서
                      // 끝나 보이던 원인이다(#669).
                      final int rows = (days.length / 7).ceil();
                      final double rowHeight = math.max(
                        _minRowHeight,
                        constraints.maxHeight / math.max(rows, 1),
                      );
                      return GridView.builder(
                        // 최소 높이에 걸려 다 담기지 않는 경우에만 스크롤이
                        // 생긴다. 어떤 경우에도 잘라내지 않는다.
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisExtent: rowHeight,
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
                            key: Key('calendar-day-${day.day}'),
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
                            // 칸 높이는 남은 공간에서 정해지므로 일정이 여럿인
                            // 날은 칩이 칸을 넘길 수 있다. 넘치는 칩은 잘라내되
                            // (clip) 레이아웃 경고 없이 날짜 숫자는 항상 남긴다.
                            clipBehavior: Clip.hardEdge,
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
                                Expanded(
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: <Widget>[
                                      for (final ScheduleEvent e in dayEvents)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheduleCategoryColor(
                                              e.category,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
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
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(
                  child: Text(
                    '일정을 불러오지 못했어요',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ),
            ),
            // 시스템 내비게이션 바 인셋만큼 더 띄운다 — 인셋이 있는 기기에서
            // 마지막 주가 내비게이션 바 뒤로 들어가 보이지 않던 문제(#669).
            SizedBox(
              height: AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
            ),
          ],
        ),
      ),
    );
  }

  /// 그 달의 그리드 칸. 앞쪽은 1일의 요일까지 비우고, 뒤쪽도 마지막 주가 7칸이
  /// 되도록 채운다 — 채우지 않으면 마지막 주의 테두리가 중간에서 끊긴다.
  static List<DateTime?> _daysInGrid(DateTime month) {
    final first = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leading = first.weekday % 7; // Sunday-first
    final trailing = (7 - (leading + lastDay.day) % 7) % 7;
    return <DateTime?>[
      for (int i = 0; i < leading; i++) null,
      for (int d = 1; d <= lastDay.day; d++)
        DateTime(month.year, month.month, d),
      for (int i = 0; i < trailing; i++) null,
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
