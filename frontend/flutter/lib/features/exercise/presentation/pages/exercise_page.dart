import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/features/notification/presentation/widgets/notification_panel.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/right_slide_panel.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// Localized label for a workout type badge.
String _typeLabel(AppLocalizations l, ExerciseType t) => switch (t) {
  ExerciseType.cardio => l.exTypeCardio,
  ExerciseType.strength => l.exTypeStrength,
  ExerciseType.yoga => l.exTypeYoga,
  ExerciseType.walking => l.exTypeWalking,
  ExerciseType.stretching => l.exTypeStretching,
  ExerciseType.other => l.exTypeOther,
};

/// 운동 tab, rebuilt to the On-Care Figma redesign — a 운동 기록 / 헬스장
/// sub-tab switcher over a weekly summary, stacked activity chart, AI routine,
/// today's logs, and the gym card.
class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  int _subTab = 0; // 0 = 운동 기록, 1 = 헬스장
  String? _slot;

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
                  _RecordTab(onAdd: () => showExerciseAddSheet(context))
                else
                  _GymTab(
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

class _RecordTab extends ConsumerWidget {
  const _RecordTab({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<ExerciseWeek> weekAsync = ref.watch(exerciseWeekProvider);
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
              style: const TextStyle(fontSize: 13, color: FigmaColors.textMuted),
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
                    label: l.exThisWeek,
                    value: '${week.sessions.length}',
                    unit: l.exUnitCount,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: l.exStatTime,
                    value: '${week.totalMinutes}',
                    unit: l.unitMinutes,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: l.exStatCalories,
                    value: '${week.totalCalories}',
                    unit: l.unitKcal,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: <Widget>[
                Text(
                  l.exActivityTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l.exThisWeek,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ActivityChart(week: week),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ExerciseFeedback(message: week.aiCoachMessage),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _AiRoutine(onAdd: onAdd),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _TodayLogs(sessions: week.sessions),
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
    this.accent = false,
    this.streak = false,
  });

  final String label;
  final String value;
  final String unit;
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
        boxShadow: streak
            ? <BoxShadow>[
                BoxShadow(
                  color: FigmaColors.heartOrange.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
          Text(
            value,
            style: TextStyle(
              fontSize: accent ? 13 : 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: streak
                  ? Colors.white.withValues(alpha: 0.85)
                  : accent
                  ? FigmaColors.primary.withValues(alpha: 0.7)
                  : FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.week});

  final ExerciseWeek week;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int n = week.dailyMinutes.length;
    final bool hasBreakdown =
        n > 0 &&
        week.cardioMinutes.length == n &&
        week.strengthMinutes.length == n &&
        week.stretchingMinutes.length == n;
    final List<_Bar> bars = <_Bar>[
      for (int i = 0; i < n; i++)
        if (hasBreakdown)
          _Bar(
            week.cardioMinutes[i],
            week.strengthMinutes[i],
            week.stretchingMinutes[i],
          )
        else
          _Bar(week.dailyMinutes[i], 0, 0),
    ];
    // Localized weekday fallback (월~일) for when the backend sends no labels.
    final List<String> fallbackDays = <String>[
      l.dietWeekdayMon,
      l.dietWeekdayTue,
      l.dietWeekdayWed,
      l.dietWeekdayThu,
      l.dietWeekdayFri,
      l.dietWeekdaySat,
      l.dietWeekdaySun,
    ];
    final List<String> dayLabels = week.dayLabels.length == n
        ? week.dayLabels
        : fallbackDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FigmaColors.primaryA(0.10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: FigmaColors.primaryA(0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _StackedBarPainter(
                bars: bars,
                dayLabels: dayLabels,
                todayIndex: n - 1,
                todayLabel: l.exToday,
              ),
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
    const double barW = 26;
    for (int i = 0; i < bars.length; i++) {
      final _Bar b = bars[i];
      final double cx = left + slot * i + slot / 2;
      final double x = cx - barW / 2;
      final bool isToday = i == todayIndex;
      double yBottom = chartH;
      double h;
      // stretch (light, bottom)
      h = (b.stretch / max) * chartH;
      if (h > 0) {
        _rrect(canvas, x, yBottom - h, barW, h, const Color(0xFFD4EEF8), 3);
        yBottom -= h;
      }
      // strength (dark mid)
      h = (b.strength / max) * chartH;
      if (h > 0) {
        _rrect(canvas, x, yBottom - h, barW, h, const Color(0xFF1B6FA8), 0);
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
          isToday ? const Color(0xFF2190C4) : FigmaColors.primary,
          3,
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

class _AiRoutine extends StatelessWidget {
  const _AiRoutine({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              l.exAiRoutineToday,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: FigmaColors.ink,
              ),
            ),
            const Spacer(),
            const Text(
              '1/3',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: FigmaColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: FigmaColors.primary,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.add, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        l.exAddExercise,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Fill33(),
        const SizedBox(height: 16),
        _RoutineCard(
          title: l.exRoutineBriskTitle,
          subtitle: l.exRoutineBriskSub,
          done: true,
        ),
        const SizedBox(height: 10),
        _RoutineCard(
          title: l.exRoutineStretchTitle,
          subtitle: l.exRoutineStretchSub,
          minutes: l.exDurationMinutes(10),
        ),
        const SizedBox(height: 10),
        _RoutineCard(
          title: l.exRoutineStrengthTitle,
          subtitle: l.exRoutineStrengthSub,
          minutes: l.exDurationMinutes(15),
        ),
      ],
    );
  }
}

class _Fill33 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 5,
        child: Row(
          children: <Widget>[
            const Expanded(
              flex: 33,
              child: ColoredBox(color: FigmaColors.primary),
            ),
            Expanded(
              flex: 67,
              child: ColoredBox(color: FigmaColors.primaryA(0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.title,
    required this.subtitle,
    this.done = false,
    this.minutes,
  });

  final String title;
  final String subtitle;
  final bool done;
  final String? minutes;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done ? FigmaColors.primaryA(0.15) : FigmaColors.hairline,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          if (done)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: FigmaColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 15, color: Colors.white),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF6FBFE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FigmaColors.primaryA(0.3), width: 2),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: done ? FigmaColors.textFaint : FigmaColors.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: done ? FigmaColors.textFaint : FigmaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (done)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: FigmaColors.statusGreen,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.check, size: 9, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    l.exMissionComplete,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (minutes != null)
            Text(
              minutes!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FigmaColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayLogs extends StatelessWidget {
  const _TodayLogs({required this.sessions});

  final List<ExerciseSession> sessions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.exExerciseLog,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l.exEmptyLog,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textMuted,
                ),
              ),
            ),
          )
        else
          for (final ExerciseSession s in sessions) ...<Widget>[
            _LogCard(
              tag: _typeLabel(l, s.type),
              time: s.timeLabel ?? s.dateLabel ?? s.dayLabel,
              kcal: s.calories,
              items: s.items.isNotEmpty
                  ? s.items
                  : <String>[l.exMinutesExercise(s.minutes)],
              session: s,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.tag,
    required this.time,
    required this.kcal,
    required this.items,
    this.session,
  });

  final String tag;
  final String time;
  final int kcal;
  final List<String> items;
  final ExerciseSession? session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textFaint,
                ),
              ),
              const Spacer(),
              Text(
                l.unitKcalValue(kcal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showExerciseAddSheet(context, session: session),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: FigmaColors.textFaint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FigmaColors.hairline),
          const SizedBox(height: 12),
          for (final String it in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
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
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── 헬스장 ──

class _GymTab extends ConsumerWidget {
  const _GymTab({
    required this.selectedSlot,
    required this.onSlot,
    required this.onFind,
  });

  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<Gym?> gymAsync = ref.watch(myGymProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onFind,
              style: FilledButton.styleFrom(
                backgroundColor: FigmaColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.search, size: 16),
              label: Text(
                l.exFindGym,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          gymAsync.when(
            loading: () => const _GymLoading(),
            error: (Object e, StackTrace _) =>
                _GymError(onRetry: () => ref.invalidate(myGymProvider)),
            data: (Gym? gym) => gym == null
                ? const _GymEmpty()
                : _MyGymCard(
                    gym: gym,
                    selectedSlot: selectedSlot,
                    onSlot: onSlot,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The "내 헬스장" card, driven by a real [Gym] from `myGymProvider` while
/// keeping the Figma styling (white card, trainer row, AI 예약 배너, actions).
class _MyGymCard extends StatelessWidget {
  const _MyGymCard({
    required this.gym,
    required this.selectedSlot,
    required this.onSlot,
  });

  final Gym gym;
  final String? selectedSlot;
  final ValueChanged<String> onSlot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String trainer = gym.trainerName ?? l.exTrainer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.place_outlined,
                size: 15,
                color: FigmaColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l.exMyGym,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            gym.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '📍 ${gym.address} · ${gym.distanceKm.toStringAsFixed(1)}km',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
          if (gym.weekdayHours != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '🕐 ${l.exGymWeekdayHours(gym.weekdayHours!)}'
              '${gym.weekendHours != null ? ' · ${l.exGymWeekendHours(gym.weekendHours!)}' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textMuted,
              ),
            ),
          ],
          if (gym.phone != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '📞 ${gym.phone}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: FigmaColors.textMuted,
              ),
            ),
          ],
          if (gym.trainerName != null) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: FigmaColors.textFaint,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      gym.trainerName!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.ink,
                      ),
                    ),
                    Text(
                      gym.trainerRole ?? l.exTrainerDedicated,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (gym.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String t in gym.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: FigmaColors.primaryA(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  FigmaColors.bannerStart,
                  FigmaColors.bannerEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FigmaColors.primaryA(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      l.exAiSlotTitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.exTrainerAvailability(trainer),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final List<String> s in <List<String>>[
                      <String>[l.exSlotToday19, l.exSlot1Left],
                      <String>[l.exSlotTomorrow0730, l.exSlotAvailable],
                      <String>[l.exSlotTomorrow20, l.exSlot2Left],
                    ])
                      _SlotChip(
                        label: s[0],
                        sub: s[1],
                        selected: selectedSlot == s[0],
                        onTap: () => onSlot(s[0]),
                      ),
                  ],
                ),
                if (selectedSlot != null) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l.exReserveConfirmedSlotGym(
                                selectedSlot!,
                                gym.name,
                              ),
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: FigmaColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l.exReserveConfirm(selectedSlot!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: FigmaColors.hairline),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showGymInfoSheet(context, gym),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FigmaColors.primary,
                    backgroundColor: FigmaColors.softBlue,
                    side: BorderSide(color: FigmaColors.primaryA(0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l.exGymInfo,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => showGymChatSheet(context, gym: gym),
                  style: FilledButton.styleFrom(
                    backgroundColor: FigmaColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l.exConsultButton,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Spinner shown while `myGymProvider` resolves.
class _GymLoading extends StatelessWidget {
  const _GymLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

/// Retry state shown when `myGymProvider` fails.
class _GymError extends StatelessWidget {
  const _GymError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: <Widget>[
          Text(
            l.exGymLoadError,
            style: const TextStyle(fontSize: 13, color: FigmaColors.textMuted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              side: BorderSide(color: FigmaColors.primaryA(0.4)),
            ),
            child: Text(l.actionRetry),
          ),
        ],
      ),
    );
  }
}

/// Empty state shown when the user has no registered gym.
class _GymEmpty extends StatelessWidget {
  const _GymEmpty();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FigmaColors.primaryA(0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.fitness_center,
              size: 24,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l.exNoGymTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.exNoGymSub,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? FigmaColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? null
              : Border.all(color: FigmaColors.primaryA(0.25)),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: FigmaColors.primaryA(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : FigmaColors.ink,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white.withValues(alpha: 0.8)
                    : FigmaColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
