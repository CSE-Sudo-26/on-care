import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_date_nav_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 7-day picker centred on today, mirroring the user app's Diet tab
/// strip: chevrons shift the window a week at a time, the selected day
/// fills primary, today reads primary. A dot marks days with booked
/// sessions. Cells are flexible so the row never overflows.
///
/// 일 보기 상단의 날짜 스트립 — 날짜 내비게이션 행 + 7일 셀.
///
/// 주 보기와 같은 구성이다: 왼쪽에 [ScheduleDateNavBar] 의
/// `◀ 날짜 범위 ▶`, 오른쪽 끝에 [trailing]. 요일 칸은 폭 전체를 나눠 쓴다 — 한때 460px 상한으로 좁혀 둔
/// 적이 있는데(#859), 넓은 콘솔에서 오른쪽이 통째로 비어 날짜를 좁힐 이유가
/// 없다는 것만 확인하고 되돌렸다(#882).
class ScheduleWeekStrip extends StatelessWidget {
  const ScheduleWeekStrip({
    super.key,
    required this.weekAnchor,
    required this.selectedDay,
    required this.bookedDates,
    required this.onSelect,
    required this.onShiftWeek,
    required this.trailing,
  });

  /// 날짜 내비게이션 행 오른쪽 끝에 붙는 컨트롤(`오늘`·`일|주`). 오른쪽 끝은
  /// 아래 요일 칸 그리드의 오른쪽 끝과 맞는다. (#882)
  final Widget trailing;

  /// Leftmost visible day (today − 3 by default).
  final DateTime weekAnchor;

  /// The day currently highlighted and shown on the timeline.
  final DateTime selectedDay;

  /// `YYYY-MM-DD` dates that have at least one booked session.
  final Set<String> bookedDates;

  /// Called when the user taps a day cell.
  final ValueChanged<DateTime> onSelect;

  /// `-1` = previous week, `+1` = next week.
  final ValueChanged<int> onShiftWeek;

  /// 요일 라벨은 로케일을 따르므로 const 로 둘 수 없다. (#501)
  static List<String> _weekdayShort(AppLocalizations l) => weekdayNames(l);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final today = nowKst();
    final week = <DateTime>[
      for (var i = 0; i < 7; i++) weekAnchor.add(Duration(days: i)),
    ];
    final end = weekAnchor.add(const Duration(days: 6));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 주 보기와 같은 행을 쓴다 — 두 보기가 날짜와 컨트롤을 같은 자리에
        // 둔다는 규칙이 한 위젯에 모여 있어 갈라질 수 없다.
        ScheduleDateNavBar(
          start: weekAnchor,
          end: end,
          onShift: onShiftWeek,
          trailing: trailing,
        ),
        const SizedBox(height: AppSpacing.xs),
        // Flexible cells share the row evenly — no fixed widths that
        // could overflow a narrow column.
        Row(
          children: <Widget>[
            for (final d in week)
              Expanded(
                child: _DayCell(
                  date: d,
                  label: _weekdayShort(l)[d.weekday - 1],
                  selected: _isSameDay(d, selectedDay),
                  isToday: _isSameDay(d, today),
                  hasDot: bookedDates.contains(ymd(d)),
                  onTap: () => onSelect(d),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.label,
    required this.selected,
    required this.isToday,
    required this.hasDot,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final bool selected;
  final bool isToday;
  final bool hasDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayColor = selected
        ? AppColors.primaryForeground
        : (isToday ? AppColors.primary : AppColors.foreground);
    final labelColor = selected
        ? AppColors.primaryForeground.withValues(alpha: 0.85)
        : (isToday ? AppColors.primary : AppColors.subtleForeground);

    return InkWell(
      key: ValueKey<String>('schedule-day-${ymd(date)}'),
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: const BorderRadius.all(AppRadius.lg),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: dayColor,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasDot
                    ? (selected
                          ? AppColors.primaryForeground
                          : AppColors.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
