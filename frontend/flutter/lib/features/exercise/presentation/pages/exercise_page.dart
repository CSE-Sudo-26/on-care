import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// NumberFormat 만 가져온다 — intl 의 TextDirection 이 dart:ui 것과 충돌한다.
import 'package:intl/intl.dart' show NumberFormat;

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/features/exercise/presentation/widgets/gym_tab.dart';
import 'package:oncare/features/notification/presentation/widgets/notification_panel.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/right_slide_panel.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// 운동 tab, rebuilt to the On-Care Figma redesign — a 운동 기록 / 헬스장
/// sub-tab switcher over a weekly summary, stacked activity chart, AI routine,
/// today's logs, and the gym card.
class ExercisePage extends StatefulWidget {
  const ExercisePage({this.initialSubTab = 0, super.key});

  final int initialSubTab;

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  late int _subTab = widget.initialSubTab; // 0 = 운동 기록, 1 = 헬스장
  String? _slot;

  @override
  void didUpdateWidget(covariant ExercisePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      _subTab = widget.initialSubTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 108),
              children: <Widget>[
                FigmaTabHeader(
                  title: l.pageExerciseTitle,
                  onBell: () => showRightSlidePanel<void>(
                    context,
                    content: const NotificationPanelBody(),
                  ),
                  onCalendar: () => showScheduleCalendarSheet(context),
                ),
                _SubTabs(
                  active: _subTab,
                  onChanged: (int i) => setState(() => _subTab = i),
                ),
                const SizedBox(height: 16),
                if (_subTab == 0)
                  const _RecordTab()
                else
                  GymTab(
                    selectedSlot: _slot,
                    onSlot: (String s) =>
                        setState(() => _slot = _slot == s ? null : s),
                    onFind: () => showGymLocatorSheet(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubTabs extends StatelessWidget {
  const _SubTabs({required this.active, required this.onChanged});
  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x12000000), width: 1.5),
          ),
        ),
        child: Row(
          children: <Widget>[
            _tab(0, Icons.event_note_outlined, l.exExerciseLog),
            _tab(1, Icons.place_outlined, l.exGymTab),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i, IconData icon, String label) {
    final bool on = active == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(i),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: on ? FigmaColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: on ? FigmaColors.primary : FigmaColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: on ? FigmaColors.ink : FigmaColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── 운동 기록 ──

class _RecordTab extends ConsumerStatefulWidget {
  const _RecordTab();

  @override
  ConsumerState<_RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends ConsumerState<_RecordTab> {
  // 주간 달력에서 선택한 날짜(기본=오늘)와 주 단위 이동.
  late DateTime _selected = _today;
  int _weekShift = 0;

  DateTime get _today {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _toggleRoutine(int i) {
    final List<bool> cur = ref.read(exerciseRoutineDoneProvider);
    final List<bool> next = List<bool>.of(cur);
    if (i >= 0 && i < next.length) next[i] = !next[i];
    ref.read(exerciseRoutineDoneProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 저장소 주간 데이터에 오늘 체크한 AI 추천 운동을 더한 단일 소스. 주간 요약
    // 카드·오늘 도넛·이번 주 차트가 모두 여기서 나오고, 홈 운동 카드도 같은
    // provider 를 읽는다([0]=어깨 스트레칭 8분, [1]=인터벌 러닝 30분).
    final AsyncValue<ExerciseWeek> weekAsync = ref.watch(
      exerciseWeekViewProvider,
    );
    final List<bool> routineDone = ref.watch(exerciseRoutineDoneProvider);
    // 주간 소모 목표는 서버(exercise_burn_goal)에서 온다. 홈 운동 카드도 같은
    // 값을 읽어 두 화면의 목표치가 어긋나지 않는다. 로딩 전에는 엔티티 기본값.
    final int burnGoal =
        ref.watch(dashboardSummaryProvider).valueOrNull?.exerciseBurnGoal ??
        DashboardSummary.defaultExerciseBurnGoal;
    final DateTime today = _today;
    final DateTime center = today.add(Duration(days: _weekShift * 7));
    final bool atToday = _weekShift == 0 && _selected == today;
    return weekAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
      error: (Object e, StackTrace _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: <Widget>[
            Text(
              l.exLoadError,
              style: const TextStyle(
                fontSize: 13,
                color: FigmaColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => ref.invalidate(exerciseWeekProvider),
              style: OutlinedButton.styleFrom(
                foregroundColor: FigmaColors.primary,
                side: BorderSide(color: FigmaColors.primaryA(0.4)),
              ),
              child: Text(l.actionRetry),
            ),
          ],
        ),
      ),
      data: (ExerciseWeek week) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 0) 운동 주간 달력 (식단 탭과 동일한 스타일)
          _ExerciseWeekStrip(
            center: center,
            selected: _selected,
            today: today,
            showTodayButton: !atToday,
            onSelect: (DateTime d) => setState(() => _selected = d),
            onToday: () => setState(() {
              _weekShift = 0;
              _selected = today;
            }),
            onPrev: () => setState(() => _weekShift -= 1),
            onNext: _weekShift >= 0
                ? null
                : () => setState(() => _weekShift += 1),
          ),
          const SizedBox(height: 8),
          if (!atToday)
            const _ExerciseOtherDay()
          else ...<Widget>[
            // 1) 이번 주 운동 요약
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                l.exWeekSummary,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _StatCard(
                      label: l.exStatDays,
                      // 운동 일수 = 운동한 활성 일수(workoutCount). 하루에 유형을
                      // 나눠 여러 세션으로 기록해도 1일로 센다(요일 수).
                      // 홈 운동 카드의 '주간 운동 일수'와 동일한 정의.
                      value: '${week.workoutCount}',
                      unit: l.unitDays,
                      goal: '3', // 주 3일 이상
                      accent: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: l.exStatTime,
                      value: '${week.totalMinutes}',
                      unit: l.unitMinutes,
                      goal: '150',
                      accent: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: l.exStatCalories,
                      value: '${week.totalCalories}',
                      unit: l.unitKcal,
                      goal: NumberFormat('#,###').format(burnGoal),
                      accent: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: l.exStatStreak,
                      value: '${week.streakDays}',
                      unit: l.exUnitStreakDays,
                      streak: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 2) AI 피드백
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ExerciseFeedback(message: week.aiCoachMessage),
            ),
            const SizedBox(height: 20),
            // 3) 운동 현황 (오늘 / 이번 주 / 이번 달)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ActivityStatus(week: week),
            ),
            const SizedBox(height: 20),
            // 4) 오늘 완료한 PT 일지 (트레이너 연동)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: _PtLogCard(),
            ),
            const SizedBox(height: 20),
            // 5) PT 맞춤 연계 AI 루틴
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PtAiRoutineCard(
                done: routineDone,
                onToggle: _toggleRoutine,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Weekly date strip for the 운동 기록 tab, mirroring the 식단 tab calendar:
/// the current week centred on today, with the selected day highlighted and a
/// "오늘" reset chip when a non-today day is picked. Controlled by [_RecordTab].
class _ExerciseWeekStrip extends StatelessWidget {
  const _ExerciseWeekStrip({
    required this.center,
    required this.selected,
    required this.today,
    required this.showTodayButton,
    required this.onSelect,
    required this.onToday,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime center;
  final DateTime selected;
  final DateTime today;
  final bool showTodayButton;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  int _weekOfMonth(DateTime d) {
    final DateTime first = DateTime(d.year, d.month);
    final int offset = first.weekday - 1;
    return ((d.day + offset - 1) / 7).floor() + 1;
  }

  String _weekday(AppLocalizations l, int weekday) => switch (weekday) {
    1 => l.dietWeekdayMon,
    2 => l.dietWeekdayTue,
    3 => l.dietWeekdayWed,
    4 => l.dietWeekdayThu,
    5 => l.dietWeekdayFri,
    6 => l.dietWeekdaySat,
    _ => l.dietWeekdaySun,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => center.add(Duration(days: i - 3)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  l.dietWeekLabel(center.month, _weekOfMonth(center)),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textSub,
                  ),
                ),
                if (showTodayButton)
                  GestureDetector(
                    onTap: onToday,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: FigmaColors.primaryA(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: FigmaColors.primaryA(0.25)),
                      ),
                      child: Text(
                        l.dietToday,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _Arrow(icon: Icons.chevron_left, onTap: onPrev),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (final DateTime d in days)
                      _WeekDay(
                        day: d,
                        label: _weekday(l, d.weekday),
                        isToday: d == today,
                        isSelected: d == selected,
                        onTap: () => onSelect(d),
                      ),
                  ],
                ),
              ),
              _Arrow(icon: Icons.chevron_right, onTap: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular week-navigation arrow, dimmed when disabled (onTap == null).
class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: FigmaColors.softBlue,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 16, color: FigmaColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Shown when a non-today date is selected in the 운동 주간 달력 — mirrors the
/// 식단 탭's empty state (same copy, 식단→운동).
class _ExerciseOtherDay extends StatelessWidget {
  const _ExerciseOtherDay();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Text(
          // 식단 탭과 같은 문구를 공유하고 섹션 이름만 바꿔 끼운다.
          l.otherDateEmpty(l.pageExerciseTitle),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: FigmaColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.day,
    required this.label,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final String label;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color labelColor = isSelected || isToday
        ? FigmaColors.primary
        : FigmaColors.textFaint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? FigmaColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected ? kCardShadow : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? FigmaColors.primary
                    : FigmaColors.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.goal,
    this.accent = false,
    this.streak = false,
  });

  final String label;
  final String value;
  final String unit;

  /// Optional small "/목표" suffix shown after the value (e.g. "/150").
  final String? goal;
  final bool accent;
  final bool streak;

  @override
  Widget build(BuildContext context) {
    final Color bg = streak
        ? FigmaColors.heartOrange
        : accent
        ? FigmaColors.primaryA(0.07)
        : FigmaColors.statBg;
    final Color valueColor = streak
        ? Colors.white
        : accent
        ? FigmaColors.primary
        : FigmaColors.ink;
    final Color labelColor = streak
        ? Colors.white.withValues(alpha: 0.8)
        : FigmaColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: streak
            ? null
            : Border.all(
                color: accent
                    ? FigmaColors.primaryA(0.15)
                    : FigmaColors.hairline,
              ),
        boxShadow: streak ? kCardShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
              if (streak) const Text('🔥', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          // Value with the unit inline to its right → one line shorter.
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: accent ? 14 : 16,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    height: 1,
                    letterSpacing: -0.4,
                  ),
                ),
                if (goal != null)
                  TextSpan(text: ' /$goal$unit', style: kGoalSuffixStyle)
                else
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: streak
                          ? Colors.white.withValues(alpha: 0.85)
                          : accent
                          ? FigmaColors.primary.withValues(alpha: 0.7)
                          : FigmaColors.textMuted,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A period of the "운동 현황" chart: the stacked bars, their x-labels, and
/// which bar (if any) represents "now" for the highlight/label.
class _ChartPeriod {
  const _ChartPeriod(this.bars, this.labels, this.todayIndex);
  final List<_Bar> bars;
  final List<String> labels;
  final int todayIndex;
}

/// "운동 현황" with an 오늘 / 이번 주 / 이번 달 segmented switcher over the same
/// stacked-bar chart. All three views share the chart's legend and styling so
/// the section stays visually consistent with the rest of the tab.
class _ActivityStatus extends StatefulWidget {
  const _ActivityStatus({required this.week});

  /// Weekly data with today's checked AI routines already folded in
  /// (`exerciseWeekViewProvider`), so the 오늘 donut, the 이번 주 chart and the
  /// 주간 요약 tiles above all read the same numbers.
  final ExerciseWeek week;

  @override
  State<_ActivityStatus> createState() => _ActivityStatusState();
}

class _ActivityStatusState extends State<_ActivityStatus> {
  int _period = 1; // 0 = 오늘, 1 = 이번 주, 2 = 이번 달

  /// 오늘 요일 인덱스(0=월 … 6=일)를 이번 주 범위로 클램프. 홈 주간추이와 같은
  /// 실제 오늘을 가리키도록 해, '오늘=일 고정' 문제를 없앤다.
  int _weekTodayIndex(int n) =>
      n <= 0 ? -1 : (DateTime.now().weekday - 1).clamp(0, n - 1);

  bool get _hasBreakdown {
    final ExerciseWeek w = widget.week;
    final int n = w.dailyMinutes.length;
    return n > 0 &&
        w.cardioMinutes.length == n &&
        w.strengthMinutes.length == n &&
        w.stretchingMinutes.length == n;
  }

  /// 오늘의 유형별 활동 분. 주간 데이터에서 그대로 읽으므로 오늘 도넛과
  /// 이번 주 차트의 오늘 막대가 언제나 같은 값이다.
  double _today(List<double> series) {
    final int i = _weekTodayIndex(widget.week.dailyMinutes.length);
    return i >= 0 && i < series.length ? series[i] : 0;
  }

  List<_Bar> _weekBars() {
    final ExerciseWeek w = widget.week;
    final int n = w.dailyMinutes.length;
    final bool hasBreakdown = _hasBreakdown;
    return <_Bar>[
      for (int i = 0; i < n; i++)
        if (hasBreakdown)
          _Bar(w.cardioMinutes[i], w.strengthMinutes[i], w.stretchingMinutes[i])
        else
          _Bar(w.dailyMinutes[i], 0, 0),
    ];
  }

  _ChartPeriod _dataFor(int period) {
    switch (period) {
      case 2: // 이번 달 — weekly buckets
        return const _ChartPeriod(
          <_Bar>[
            _Bar(120, 40, 30),
            _Bar(95, 60, 20),
            _Bar(140, 45, 35),
            _Bar(90, 55, 25),
            _Bar(60, 40, 20),
          ],
          <String>['1주', '2주', '3주', '4주', '5주'],
          -1,
        );
      default: // 이번 주
        return _ChartPeriod(
          _weekBars(),
          widget.week.dayLabels,
          _weekTodayIndex(widget.week.dailyMinutes.length),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              l.exActivityTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: FigmaColors.ink,
              ),
            ),
            const Spacer(),
            _PeriodToggle(
              active: _period,
              labels: <String>[l.exToday, l.exThisWeek, l.exThisMonth],
              onChanged: (int i) => setState(() => _period = i),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 오늘 = 도넛(카테고리 비중), 이번 주/이번 달 = 막대차트.
        if (_period == 0)
          _TodayDonut(
            segs: <_DonutSeg>[
              _DonutSeg(
                l.exTypeCardio,
                _today(
                  _hasBreakdown
                      ? widget.week.cardioMinutes
                      : widget.week.dailyMinutes,
                ).round(),
                FigmaColors.primary,
              ),
              _DonutSeg(
                l.exTypeStrength,
                _today(widget.week.strengthMinutes).round(),
                const Color(0xFF1B6FA8),
              ),
              _DonutSeg(
                l.exTypeStretching,
                _today(widget.week.stretchingMinutes).round(),
                const Color(0xFFD4EEF8),
              ),
            ],
          )
        else
          Builder(
            builder: (BuildContext context) {
              final _ChartPeriod data = _dataFor(_period);
              return _ActivityChart(
                bars: data.bars,
                dayLabels: data.labels,
                todayIndex: data.todayIndex,
              );
            },
          ),
      ],
    );
  }
}

/// "오늘" 뷰: 왼쪽 도넛(오늘 운동 카테고리 비중) + 오른쪽 카테고리별 시간.
/// 카드 안에서 도넛+시간 묶음을 가운데 정렬한다.
class _TodayDonut extends StatelessWidget {
  const _TodayDonut({required this.segs});

  final List<_DonutSeg> segs;

  @override
  Widget build(BuildContext context) {
    final int total = segs.fold<int>(0, (int a, _DonutSeg s) => a + s.minutes);
    return Container(
      // 이번 주/이번 달 막대 차트 카드와 동일하게 가로 전체를 채운다(오늘 카드만
      // 내용 폭으로 좁아 보이던 문제 수정). 도넛+범례는 FittedBox 로 가운데 정렬.
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.primaryA(0.10)),
        boxShadow: kCardShadow,
      ),
      child: SizedBox(
        height: 170,
        // Scale down on narrow screens so the fixed-width donut + legend never
        // overflows, while keeping the centred wide-gap layout on wide viewports.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CustomPaint(
                      size: const Size.square(116),
                      painter: _DonutPainter(segs),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.ink,
                            height: 1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          '분',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: FigmaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              SizedBox(
                width: 160,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '오늘 총 운동 시간',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final _DonutSeg s in segs) ...<Widget>[
                      _DonutLegendRow(seg: s),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutSeg {
  const _DonutSeg(this.label, this.minutes, this.color);
  final String label;
  final int minutes;
  final Color color;
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({required this.seg});
  final _DonutSeg seg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: seg.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            seg.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textSub,
            ),
          ),
        ),
        Text(
          '${seg.minutes}분',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.segs);
  final List<_DonutSeg> segs;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = segs.fold<double>(
      0,
      (double a, _DonutSeg s) => a + s.minutes,
    );
    if (total <= 0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double stroke = 20;
    final double radius = (size.width - stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double gap = 0.06; // radians of spacing between segments
    const double full = 2 * math.pi;
    double start = -math.pi / 2; // top (12 o'clock)
    for (final _DonutSeg s in segs) {
      // Skip 0-minute categories (a checked routine may zero one out); a
      // negative sweep would otherwise paint a stray rounded dot.
      if (s.minutes <= 0) continue;
      final double sweep = (s.minutes / total) * full - gap;
      final Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = s.color;
      canvas.drawArc(rect, start + gap / 2, sweep, false, p);
      start += (s.minutes / total) * full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segs != segs;
}

/// Compact segmented control (오늘 / 이번 주 / 이번 달) matching the app's
/// primary-tint pill styling.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.active,
    required this.labels,
    required this.onChanged,
  });

  final int active;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active == i ? FigmaColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active == i ? Colors.white : FigmaColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({
    required this.bars,
    required this.dayLabels,
    required this.todayIndex,
  });

  final List<_Bar> bars;
  final List<String> dayLabels;
  final int todayIndex;

  /// Hover tooltip content for a bar — one line per activity type as
  /// [color square] 종류   N분 (see the legend).
  List<InlineSpan> _tipSpans(AppLocalizations l, int i) {
    final _Bar b = bars[i];
    final List<({Color color, String label, int min})> rows =
        <({Color color, String label, int min})>[
          if (b.cardio > 0)
            (
              color: FigmaColors.primary,
              label: l.exTypeCardio,
              min: b.cardio.round(),
            ),
          if (b.strength > 0)
            (
              color: const Color(0xFF1B6FA8),
              label: l.exTypeStrength,
              min: b.strength.round(),
            ),
          if (b.stretch > 0)
            (
              color: const Color(0xFFD4EEF8),
              label: l.exTypeStretching,
              min: b.stretch.round(),
            ),
        ];
    if (rows.isEmpty) return const <InlineSpan>[TextSpan(text: '휴식')];
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int k = 0; k < rows.length; k++) {
      final ({Color color, String label, int min}) r = rows[k];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: r.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
      spans.add(TextSpan(text: '${r.label}   ${r.min}분'));
      if (k < rows.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.primaryA(0.10)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StackedBarPainter(
                      bars: bars,
                      dayLabels: dayLabels,
                      todayIndex: todayIndex,
                      todayLabel: l.exToday,
                    ),
                  ),
                ),
                // Transparent per-bar hover regions aligned to the painter's
                // slots (left axis pad = 24, label strip = bottom 24).
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 24),
                    child: Row(
                      children: <Widget>[
                        for (int i = 0; i < bars.length; i++)
                          Expanded(
                            child: Tooltip(
                              richMessage: TextSpan(
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FigmaColors.ink,
                                  height: 1.15,
                                ),
                                children: _tipSpans(l, i),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F3F5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: FigmaColors.hairline),
                                boxShadow: kCardShadow,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Legend(color: FigmaColors.primary, label: l.exTypeCardio),
              const SizedBox(width: 16),
              _Legend(color: const Color(0xFF1B6FA8), label: l.exTypeStrength),
              const SizedBox(width: 16),
              _Legend(
                color: const Color(0xFFD4EEF8),
                label: l.exTypeStretching,
              ),
            ],
          ),
        ],
      ),
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
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: FigmaColors.textSub,
          ),
        ),
      ],
    );
  }
}

class _Bar {
  const _Bar(this.cardio, this.strength, this.stretch);
  final double cardio;
  final double strength;
  final double stretch;
}

class _StackedBarPainter extends CustomPainter {
  const _StackedBarPainter({
    required this.bars,
    required this.dayLabels,
    required this.todayIndex,
    required this.todayLabel,
  });

  final List<_Bar> bars;
  final List<String> dayLabels;
  final int todayIndex;

  /// Resolved in the widget's build (CustomPainter has no BuildContext).
  final String todayLabel;

  /// Round the busiest day up to the next 20-minute step so bars never clip;
  /// falls back to 90 when there's no data yet.
  double get _max {
    double m = 0;
    for (final _Bar b in bars) {
      final double total = b.cardio + b.strength + b.stretch;
      if (total > m) m = total;
    }
    if (m <= 0) return 90;
    return (m / 20).ceil() * 20;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const double left = 24;
    const double bottomPad = 24;
    final double chartH = size.height - bottomPad;
    final double chartW = size.width - left;
    final double max = _max;
    final List<double> grids = <double>[
      max,
      max * 0.75,
      max * 0.5,
      max * 0.25,
      0,
    ];

    const TextStyle gridStyle = TextStyle(
      fontSize: 8,
      color: FigmaColors.textFaint,
    );
    for (final double g in grids) {
      final double y = chartH - (g / max) * chartH;
      final Paint line = Paint()
        ..color = const Color(0x0F000000)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), line);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: '${g.round()}', style: gridStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 4, y - tp.height / 2));
    }

    final double slot = chartW / bars.length;
    // Cap the bar to a fraction of the slot so bars never overlap on narrow
    // layouts or with many buckets.
    final double barW = math.min(slot * 0.6, 40);
    for (int i = 0; i < bars.length; i++) {
      final _Bar b = bars[i];
      final double cx = left + slot * i + slot / 2;
      final double x = cx - barW / 2;
      final bool isToday = i == todayIndex;
      // Only the topmost non-zero segment gets rounded top corners so every
      // bar (whatever its top category) reads with the same rounded cap.
      final bool cardioTop = b.cardio > 0;
      final bool strengthTop = !cardioTop && b.strength > 0;
      final bool stretchTop = !cardioTop && !strengthTop && b.stretch > 0;
      double yBottom = chartH;
      double h;
      // stretch (light, bottom)
      h = (b.stretch / max) * chartH;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          const Color(0xFFD4EEF8),
          stretchTop ? 4 : 0,
        );
        yBottom -= h;
      }
      // strength (dark mid)
      h = (b.strength / max) * chartH;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          const Color(0xFF1B6FA8),
          strengthTop ? 4 : 0,
        );
        yBottom -= h;
      }
      // cardio (blue top)
      h = (b.cardio / max) * chartH;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          // 유산소는 항상 동일한 브랜드 색(오늘 막대도 예외 없이).
          FigmaColors.primary,
          cardioTop ? 4 : 0,
        );
        yBottom -= h;
      }
      if (b.cardio + b.strength + b.stretch == 0) {
        _rrect(canvas, x, chartH - 3, barW, 3, const Color(0xFFEEF2F6), 1.5);
      }
      // day label
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: i < dayLabels.length ? dayLabels[i] : '',
          style: TextStyle(
            fontSize: 9,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? FigmaColors.primary : FigmaColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 5));
      if (isToday) {
        final TextPainter t2 = TextPainter(
          text: TextSpan(
            text: todayLabel,
            style: const TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              color: FigmaColors.primary,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        t2.paint(canvas, Offset(cx - t2.width / 2, chartH + 15));
      }
    }
  }

  void _rrect(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    Color color,
    double r,
  ) {
    final RRect rr = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, y, w, h),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    c.drawRRect(rr, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.dayLabels != dayLabels ||
      oldDelegate.todayIndex != todayIndex ||
      oldDelegate.todayLabel != todayLabel;
}

class _ExerciseFeedback extends StatelessWidget {
  const _ExerciseFeedback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (message.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FigmaColors.softBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FigmaColors.primaryA(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const OniAvatar(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.exAiFeedback,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.ink,
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

// ───────────────────────────────────── 오늘 완료한 PT 일지 ──

/// Trainer-linked card summarising today's completed PT session and the
/// coach's feedback. Demo scenario: 김코치님 12회차, 18:00 수업.
class _PtLogCard extends StatelessWidget {
  const _PtLogCard();

  static const List<String> _items = <String>[
    '벤치프레스 40kg · 4세트',
    '덤벨 숄더프레스 10kg · 4세트',
    '랫풀다운 45kg · 4세트',
    '플랭크 60초 · 3세트',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.fitness_center_rounded,
                size: 16,
                color: FigmaColors.primary,
              ),
              SizedBox(width: 6),
              Text(
                '오늘 완료한 PT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: <Widget>[
              _MetaChip(
                icon: Icons.check_circle,
                text: '18:00 수업 완료',
                color: FigmaColors.statusGreen,
              ),
              SizedBox(width: 6),
              _MetaChip(icon: Icons.person_outline, text: '김트레이너와 12회차'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FigmaColors.hairline),
          const SizedBox(height: 12),
          for (final String it in _items)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 3, 0, 3),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: FigmaColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    it,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3A3A4A),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FigmaColors.softBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FigmaColors.primaryA(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FigmaColors.primaryA(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 18,
                        color: FigmaColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '김트레이너',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.ink,
                          ),
                        ),
                        Text(
                          '오늘의 피드백',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: FigmaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '숄더프레스할 때 오른쪽 어깨가 들리는 경향이 있으니, 마무리할 때 '
                  '회전근개 스트레칭을 꼭 해주세요!',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.ink,
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

/// Small rounded meta chip (icon + label) used for the PT status row.
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    this.color = FigmaColors.primary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── PT 맞춤 연계 AI 루틴 ──

/// AI routine card whose two recommendations tie back to the coach's feedback
/// (오른쪽 어깨 회전근개) and today's lunch (해물 짬뽕 나트륨).
class _PtAiRoutineCard extends StatelessWidget {
  const _PtAiRoutineCard({required this.done, required this.onToggle});

  /// Completion state per recommendation ([0]=어깨 스트레칭, [1]=인터벌 러닝),
  /// owned by [_RecordTab] so checking a routine updates the 운동 현황 graph.
  final List<bool> done;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.primaryA(0.15)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Title (with AI glyph) on the left, the "반영" badge on the right.
          const Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: FigmaColors.primary),
              SizedBox(width: 6),
              Text(
                'AI 추천 운동',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
                ),
              ),
              Spacer(),
              AiPill(
                '트레이너 피드백 + 식단 반영',
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PtRoutineItem(
            icon: Icons.self_improvement,
            title: '어깨 관절 보호 스트레칭',
            minutes: '8분',
            reason: "⮕ 트레이너가 언급한 '오른쪽 어깨 회전근개' 케어",
            done: done[0],
            onToggle: () => onToggle(0),
          ),
          const SizedBox(height: 10),
          _PtRoutineItem(
            icon: Icons.directions_run,
            title: '가벼운 인터벌 러닝',
            minutes: '30분',
            reason: "⮕ 점심 '해물 짬뽕' 나트륨 배출 & 250kcal 소모",
            done: done[1],
            onToggle: () => onToggle(1),
          ),
        ],
      ),
    );
  }
}

class _PtRoutineItem extends StatelessWidget {
  const _PtRoutineItem({
    required this.icon,
    required this.title,
    required this.minutes,
    required this.reason,
    required this.done,
    required this.onToggle,
  });

  final IconData icon;
  final String title;
  final String minutes;
  final String reason;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(14),
        border: done ? Border.all(color: FigmaColors.primaryA(0.35)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Done / not-done check toggle.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? FigmaColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: done
                          ? FigmaColors.primary
                          : FigmaColors.primaryA(0.35),
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: FigmaColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: done ? FigmaColors.textFaint : FigmaColors.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.schedule,
                      size: 11,
                      color: FigmaColors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      minutes,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: FigmaColors.primaryA(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FigmaColors.primaryA(0.14)),
            ),
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: FigmaColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
