import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// NumberFormat 만 가져온다 — intl 의 TextDirection 이 dart:ui 것과 충돌한다.
import 'package:intl/intl.dart' show NumberFormat;

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/motion.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/features/exercise/presentation/widgets/gym_tab.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_card.dart';
import 'package:oncare/features/member_coach/presentation/widgets/trainer_chat_header_button.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/services/exercise_burn_goal_provider.dart';
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
                // 벨 배지는 서버 미읽음을 본다. 이 build 에는 ref 가 없어 여기서만
                // 지역적으로 얻는다 — 헤더 전체를 다시 그리지 않는다.
                Consumer(
                  builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                      FigmaTabHeader(
                        title: l.pageExerciseTitle,
                        trailingAction: const TrainerChatHeaderButton(),
                        onBell: () => context.push(AppRoutes.notification),
                        bellHasUnread:
                            (ref
                                    .watch(notificationUnreadProvider)
                                    .valueOrNull ??
                                0) >
                            0,
                        onCalendar: () => showScheduleCalendarSheet(context),
                      ),
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
        key: ValueKey<String>('exercise-subtab-$i'),
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
              // 라벨은 남는 폭 안에서 접힌다. 아이콘·라벨 둘 다 고정 폭이면
              // 320px 에서 탭 두 개가 화면을 넘겼다 — 영어(`Exercise log`)는
              // 기본 배율에서도 넘친다(#766). 아이콘은 접지 않는다.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: on ? FigmaColors.ink : AppColors.mutedForeground,
                  ),
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 주간 요약 카드·오늘 도넛·이번 주 차트가 같은 provider를 읽는다.
    final AsyncValue<ExerciseWeek> weekAsync = ref.watch(
      exerciseWeekViewProvider,
    );
    final ExerciseGoals goals = ref.watch(exerciseGoalsProvider);
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
              style: const TextStyle(fontSize: 14, color: AppColors.foreground),
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
            // 고른 날짜가 이번 주면 이미 받아 둔 주간 데이터에서, 지난 주면 그
            // 주를 따로 받아 그날의 기록을 그린다. 예전에는 데이터를 보지도 않고
            // "기록이 없어요"만 그려, 시드가 있는 날조차 비어 보였다(#671).
            _ExerciseSelectedDay(thisWeek: week, date: _selected)
          else ...<Widget>[
            // 1) 이번 주 운동 요약
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                l.exWeekSummary,
                style: const TextStyle(
                  fontSize: 15,
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
                      label: l.exStatTime,
                      value: '${week.totalMinutes}',
                      unit: l.unitMinutes,
                      goal: '${goals.minutes}',
                      accent: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: l.exStatCalories,
                      value: '${week.totalCalories}',
                      unit: l.unitKcal,
                      goal: NumberFormat('#,###').format(goals.burnCalories),
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
            // 2) 운동 현황 (오늘 / 이번 주 / 이번 달)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ActivityStatus(week: week),
            ),
            const SizedBox(height: 20),
            // 3) 오늘 완료한 PT 일지 (트레이너 피드백 포함)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: _PtLogCard(),
            ),
            const SizedBox(height: 20),
            // 4) AI 코칭 — 코칭 포인트와 추천 개인운동.
            //
            // PT 피드백 바로 다음에 둔다. `오늘 PT 에서 받은 피드백 → 그래서
            // 어떤 관리가 필요한지 → 어떤 개인운동을 하면 되는지` 가 한 흐름으로
            // 읽혀야 한다. 예전에는 조언이 맨 위, 추천 운동이 맨 아래라 그 사이를
            // 회원이 직접 이어 붙여야 했다(#782).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AiCoachingCard(coachingPoint: week.aiCoachMessage),
            ),
            const SizedBox(height: 20),
            // 5) 담당 트레이너 — 관계와 소통만. 추천 운동은 AI 코칭에 모였다.
            const CoachCard(),
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
                // 영어의 주 라벨은 한국어보다 훨씬 길다. 고정 폭으로 두면
                // 좁은 화면에서 오늘 버튼을 밀어내며 넘친다(#766).
                Flexible(
                  child: Text(
                    l.dietWeekLabel(center.month, _weekOfMonth(center)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
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
                          fontSize: 12,
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
                    // 셀마다 제 크기를 요구하면 일곱의 합이 화면을 넘는다 —
                    // 영어 요일 라벨(Mon/Tue)이 한글 한 글자보다 넓다(#766).
                    for (final DateTime d in days)
                      Expanded(
                        child: _WeekDay(
                          day: d,
                          label: _weekday(l, d.weekday),
                          isToday: d == today,
                          isSelected: d == selected,
                          onTap: () => onSelect(d),
                        ),
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

/// 운동 주간 달력에서 오늘이 아닌 날짜를 골랐을 때 그 날의 기록.
///
/// 고른 날짜가 이번 주면 이미 받아 둔 [thisWeek] 에서 그대로 읽고(추가 요청
/// 없음), 지난 주면 그 주를 따로 받는다. 정말 기록이 없는 날에만 빈 문구를
/// 남긴다.
class _ExerciseSelectedDay extends ConsumerWidget {
  const _ExerciseSelectedDay({required this.thisWeek, required this.date});

  final ExerciseWeek thisWeek;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime weekStart = mondayOfWeek(date);
    final DateTime thisMonday = mondayOfWeek(DateTime.now());
    if (weekStart == thisMonday) {
      return _ExerciseDayDetail(week: thisWeek, date: date);
    }
    return ref
        .watch(exercisePastWeekProvider(weekStart))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
          error: (Object e, StackTrace _) => const _ExerciseDayEmpty(),
          data: (ExerciseWeek week) =>
              _ExerciseDayDetail(week: week, date: date),
        );
  }
}

/// 하루치 운동 요약 — 시간·소모 칼로리·유형별 시간과 그날의 세션 목록.
class _ExerciseDayDetail extends StatelessWidget {
  const _ExerciseDayDetail({required this.week, required this.date});

  final ExerciseWeek week;
  final DateTime date;

  double _at(List<double> series, int i) =>
      i >= 0 && i < series.length ? series[i] : 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int i = date.weekday - 1; // 0 = 월
    final double minutes = _at(week.dailyMinutes, i);
    if (minutes <= 0) return const _ExerciseDayEmpty();

    final double calories = _at(week.dailyCalories, i);
    final String dayLabel = i < week.dayLabels.length ? week.dayLabels[i] : '';
    final List<ExerciseSession> sessions = week.sessions
        .where((ExerciseSession s) => s.dayLabel == dayLabel)
        .toList();
    // 유형별 비중은 `운동 현황 > 오늘` 과 같은 도넛으로 그린다. 같은 데이터를
    // 두 가지 모양으로 그리지 않도록(#682).
    final List<_DonutSeg> segs = <_DonutSeg>[
      _DonutSeg(
        l.exTypeCardio,
        _at(week.cardioMinutes, i).round(),
        FigmaColors.primary,
      ),
      _DonutSeg(
        l.exTypeStrength,
        _at(week.strengthMinutes, i).round(),
        const Color(0xFF1B6FA8),
      ),
      _DonutSeg(
        l.exTypeStretching,
        _at(week.stretchingMinutes, i).round(),
        const Color(0xFFD4EEF8),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.exDatedTitle(date.month, date.day, l.pageExerciseTitle),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  label: l.exStatTime,
                  value: '${minutes.round()}',
                  unit: l.unitMinutes,
                  accent: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: l.exStatCalories,
                  value: NumberFormat('#,###').format(calories.round()),
                  unit: l.unitKcal,
                  accent: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TodayDonut(segs: segs),
          if (sessions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            for (final ExerciseSession s in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: FigmaColors.softBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _exerciseTypeLabel(l, s.type),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: FigmaColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${s.minutes}${l.unitMinutes} · '
                        '${NumberFormat('#,###').format(s.calories)} ${l.unitKcal}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 운동 유형 → 화면 라벨. 유형별 분해 카드와 같은 문구를 쓴다.
String _exerciseTypeLabel(AppLocalizations l, ExerciseType type) =>
    switch (type) {
      ExerciseType.cardio || ExerciseType.walking => l.exTypeCardio,
      ExerciseType.strength => l.exTypeStrength,
      ExerciseType.stretching || ExerciseType.yoga => l.exTypeStretching,
      ExerciseType.other => l.exTypeCardio,
    };

/// 정말로 기록이 없는 날 — 식단 탭과 같은 문구를 공유하고 섹션 이름만 바꿔 낀다.
class _ExerciseDayEmpty extends StatelessWidget {
  const _ExerciseDayEmpty();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Text(
          l.otherDateEmpty(l.pageExerciseTitle),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: AppColors.foreground,
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
        : AppColors.mutedForeground;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 말줄임이 아니라 축소다. 'Mon' 이 'M…' 이 되면 무슨 요일인지가
          // 사라진다 — 좁아도 읽을 수 있어야 한다(#766).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
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
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? FigmaColors.primary
                    : AppColors.mutedForeground,
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
        : AppColors.mutedForeground;
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
                    fontSize: 12,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: streak
                          ? Colors.white.withValues(alpha: 0.85)
                          : accent
                          ? FigmaColors.primary.withValues(alpha: 0.7)
                          : AppColors.mutedForeground,
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

  _Bar _monthBar(double total, int day) {
    final double strengthRatio = day % 3 == 0 ? 0.30 : 0.20;
    return _Bar(
      total * 0.55,
      total * strengthRatio,
      total * (0.45 - strengthRatio),
    );
  }

  _ChartPeriod _dataFor(int period) {
    switch (period) {
      case 2: // 이번 달 — 레퍼런스처럼 일별 막대를 촘촘하게 표시한다.
        const List<double> dailyTotals = <double>[
          28,
          46,
          72,
          78,
          50,
          82,
          38,
          96,
          84,
          64,
          52,
          56,
          68,
          48,
          36,
          30,
          74,
          86,
          80,
          92,
          84,
          58,
          12,
          24,
          0,
          16,
          38,
          66,
          54,
          76,
          34,
        ];
        return _ChartPeriod(
          <_Bar>[
            for (int day = 1; day <= dailyTotals.length; day++)
              _monthBar(dailyTotals[day - 1], day),
          ],
          <String>[
            for (int day = 1; day <= dailyTotals.length; day++)
              if (day == 1 || day % 3 == 1 || day == dailyTotals.length)
                '$day'
              else
                '',
          ],
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
        // 식단 탭 `영양 요약` 의 같은 줄과 같은 구조로 둔다(#761) — 남는 폭은
        // 제목과 토글 **사이**로 가고, 둘 다 좁아지면 접힌다. `Spacer` 로 밀면
        // 정렬은 맞지만 접힐 자리가 없어 320px 에서 줄이 넘쳤다(#766).
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  l.exActivityTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
            ),
            Flexible(
              child: _PeriodToggle(
                active: _period,
                labels: <String>[l.exToday, l.exThisWeek, l.exThisMonth],
                onChanged: (int i) => setState(() => _period = i),
              ),
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
                // 주 ↔ 월 전환은 같은 위젯이 데이터만 갈아끼우므로,
                // 기간을 재생 키로 넘겨 막대를 다시 자라게 한다.
                replayKey: _period,
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
    final AppLocalizations l = AppLocalizations.of(context);
    final int total = segs.fold<int>(0, (int a, _DonutSeg s) => a + s.minutes);
    return Container(
      // 이번 주/이번 달 막대 차트 카드와 동일하게 가로 전체를 채운다(오늘 카드만
      // 내용 폭으로 좁아 보이던 문제 수정). 도넛+범례는 FittedBox 로 가운데 정렬.
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                    ChartReveal(
                      builder: (BuildContext context, double t) => CustomPaint(
                        size: const Size.square(116),
                        painter: _DonutPainter(segs, progress: t),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.ink,
                            height: 1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          l.unitMinutes,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
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
                    Text(
                      l.exTodayTotalTime,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
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
    final AppLocalizations l = AppLocalizations.of(context);
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
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
        ),
        Text(
          l.unitMinutesValue(seg.minutes),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.segs, {this.progress = 1});
  final List<_DonutSeg> segs;

  /// 0 → 1 진입 애니메이션 진행도. 12시 방향에서 시계 방향으로, 세그먼트
  /// 경계와 무관하게 한 자루의 펜이 원을 따라 그려 나가는 것처럼 보이게 한다.
  final double progress;

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
    // 원 전체 중 지금까지 그려진 각도. 각 세그먼트는 자기 구간에 해당하는
    // 만큼만 잘라 쓴다.
    final double drawn = progress.clamp(0.0, 1.0) * full;
    double start = -math.pi / 2; // top (12 o'clock)
    double consumed = 0; // 시작점에서 이 세그먼트까지의 누적 각도
    for (final _DonutSeg s in segs) {
      final double share = (s.minutes / total) * full;
      final double sweep = share - gap;
      // Skip 0-minute categories (a checked routine may zero one out); a
      // negative sweep would otherwise paint a stray rounded dot.
      if (s.minutes <= 0 || sweep <= 0) {
        start += share;
        consumed += share;
        continue;
      }
      final double visible = (drawn - consumed - gap / 2).clamp(0.0, sweep);
      if (visible > 0) {
        final Paint p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = s.color;
        canvas.drawArc(rect, start + gap / 2, visible, false, p);
      }
      start += share;
      consumed += share;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segs != segs || oldDelegate.progress != progress;
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
      // 줄 오른쪽 끝에 붙었는지를 테스트가 잴 수 있어야 한다(#766).
      key: const ValueKey<String>('exercise-period-toggle'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 좁은 화면·큰 글자 배율에서는 세 탭의 최소 폭 합이 남는 폭보다
          // 커진다. 접히게 두어야 줄이 넘치지 않는다 — 식단 탭의 같은 토글과
          // 같은 처리다(#739, #766). 보통 폭에서는 최소 폭 그대로라 모양이 같다.
          for (int i = 0; i < labels.length; i++)
            Flexible(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active == i
                        ? FigmaColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active == i
                          ? Colors.white
                          : AppColors.mutedForeground,
                    ),
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
    this.replayKey,
  });

  final List<_Bar> bars;
  final List<String> dayLabels;
  final int todayIndex;

  /// 값이 바뀌면 막대 성장 애니메이션을 처음부터 다시 재생하기 위한 키.
  final Object? replayKey;

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
    if (rows.isEmpty) return <InlineSpan>[TextSpan(text: l.exRest)];
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
      spans.add(TextSpan(text: '${r.label}   ${l.unitMinutesValue(r.min)}'));
      if (k < rows.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: bars.length > 10 ? const Key('exerciseMonthlyDailyChart') : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                  child: ChartReveal(
                    replayKey: replayKey,
                    duration: AppMotion.chartGrow,
                    // 막대별 stagger 는 painter 안에서 곡선을 적용한다.
                    curve: Curves.linear,
                    builder: (BuildContext context, double t) => CustomPaint(
                      painter: _StackedBarPainter(
                        bars: bars,
                        dayLabels: dayLabels,
                        todayIndex: todayIndex,
                        todayLabel: l.exToday,
                        progress: t,
                      ),
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
                                  fontSize: 12.5,
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
          // 범례 셋은 좁아지면 다음 줄로 넘긴다. 한 줄에 붙여 두면 320px 에서
          // 넘쳤고, 라벨을 줄이면 무슨 색이 무엇인지가 사라진다(#766).
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: <Widget>[
              _Legend(color: FigmaColors.primary, label: l.exTypeCardio),
              _Legend(color: const Color(0xFF1B6FA8), label: l.exTypeStrength),
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
    // `Wrap` 안에서는 가로 제약이 없다 — 제 폭만 차지해야 줄바꿈이 계산된다.
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        // 배율이 크면 범례 하나가 한 줄보다 넓어진다. 그때는 라벨 안에서
        // 줄을 바꾼다(#766).
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
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
    this.progress = 1,
  });

  final List<_Bar> bars;
  final List<String> dayLabels;
  final int todayIndex;

  /// Resolved in the widget's build (CustomPainter has no BuildContext).
  final String todayLabel;

  /// 0 → 1 진입 애니메이션 진행도(선형). 막대는 왼쪽부터 차례로 바닥에서
  /// 자라 오른다. 눈금선과 요일 라벨은 처음부터 그대로 둔다.
  final double progress;

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
      fontSize: 9,
      color: AppColors.mutedForeground,
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
    final bool isMonthly = bars.length > 10;
    final double barW = math.min(slot * (isMonthly ? 0.55 : 0.6), 40);
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
      // 막대별 진행도 — 각 구간 높이에 함께 곱해 스택 전체가 비율을 유지한 채
      // 바닥에서 자라 오르게 한다.
      final double t = chartStagger(progress, i, bars.length);
      double yBottom = chartH;
      double h;
      // stretch (light, bottom)
      h = (b.stretch / max) * chartH * t;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          const Color(0xFFD4EEF8),
          topRadius: stretchTop ? 4 : 0,
        );
        yBottom -= h;
      }
      // strength (dark mid)
      h = (b.strength / max) * chartH * t;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          const Color(0xFF1B6FA8),
          topRadius: strengthTop ? 4 : 0,
        );
        yBottom -= h;
      }
      // cardio (blue top)
      h = (b.cardio / max) * chartH * t;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          // 유산소는 항상 동일한 브랜드 색(오늘 막대도 예외 없이).
          FigmaColors.primary,
          topRadius: cardioTop ? 4 : 0,
        );
        yBottom -= h;
      }
      if (b.cardio + b.strength + b.stretch == 0) {
        _rrect(
          canvas,
          x,
          chartH - 3 * t,
          barW,
          3 * t,
          const Color(0xFFEEF2F6),
          topRadius: 1.5,
        );
      }
      // day label
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: i < dayLabels.length ? dayLabels[i] : '',
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? FigmaColors.primary : AppColors.mutedForeground,
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
              fontSize: 8.5,
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
    Color color, {
    required double topRadius,
  }) {
    final RRect rr = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, y, w, h),
      topLeft: Radius.circular(topRadius),
      topRight: Radius.circular(topRadius),
    );
    c.drawRRect(rr, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.dayLabels != dayLabels ||
      oldDelegate.todayIndex != todayIndex ||
      oldDelegate.todayLabel != todayLabel ||
      oldDelegate.progress != progress;
}

// ───────────────────────────────────── 오늘 완료한 PT 일지 ──

/// Trainer-linked card summarising today's completed PT session and the
/// coach's feedback. Demo scenario: 김코치님 12회차, 18:00 수업.
class _PtLogCard extends ConsumerWidget {
  const _PtLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appConfigProvider).useMockApi) {
      return const _DemoPtLogCard();
    }

    final DateTime now = DateTime.now();
    final List<CoachSession> completedToday =
        (ref.watch(coachSessionsProvider).valueOrNull ?? const <CoachSession>[])
            .where((CoachSession session) {
              final DateTime? date = session.date;
              return session.isDone &&
                  date != null &&
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
            })
            .toList(growable: false)
          ..sort(
            (CoachSession first, CoachSession second) =>
                second.time.compareTo(first.time),
          );
    if (completedToday.isEmpty) return const SizedBox.shrink();

    final MemberCoach? coach = ref.watch(memberCoachProvider).valueOrNull;
    return _CompletedPtSessionCard(
      session: completedToday.first,
      coachName: coach?.name ?? AppLocalizations.of(context).exAssignedTrainer,
    );
  }
}

class _CompletedPtSessionCard extends StatelessWidget {
  const _CompletedPtSessionCard({
    required this.session,
    required this.coachName,
  });

  final CoachSession session;
  final String coachName;

  String _programLabel(CoachProgramItem item, AppLocalizations l) {
    final String details = <String>[
      if (item.weight.isNotEmpty) item.weight,
      if (item.sets > 0) l.exProgramSets(item.sets),
      if (item.reps.isNotEmpty) item.reps,
    ].join(' · ');
    return details.isEmpty ? item.name : '${item.name} · $details';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const Key('completedPtSessionCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.fitness_center_rounded,
                size: 16,
                color: FigmaColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l.exCompletedPtTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _MetaChip(
                icon: Icons.check_circle,
                text: l.exCompletedPtTime(session.time),
                color: FigmaColors.statusGreen,
              ),
              const SizedBox(width: 6),
              _MetaChip(
                icon: Icons.timer_outlined,
                text: l.exDurationMinutes(session.durationMinutes),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FigmaColors.hairline),
          const SizedBox(height: 12),
          if (session.program.isEmpty)
            Text(
              l.exCompletedPtNoProgram,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.mutedForeground,
              ),
            )
          else
            for (final CoachProgramItem item in session.program)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 3, 0, 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: FigmaColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _programLabel(item, l),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (session.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FigmaColors.softBlue,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FigmaColors.primaryA(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l.exCompletedPtFeedback(coachName),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: FigmaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.note,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 목업 모드에서만 그리는 "오늘 완료한 PT" 카드.
///
/// 카드의 **제목·라벨**은 앱이 쓴 문구라 로케일을 따르고, 세션 내용(트레이너
/// 이름·운동 목록·피드백)은 서버가 줬을 값을 흉내 낸 **가상의 데이터**라 그대로
/// 둔다 — 실모드에서는 이 자리에 실제 회원의 기록이 들어온다(#847).
class _DemoPtLogCard extends StatelessWidget {
  const _DemoPtLogCard();

  static const List<String> _items = <String>[
    '벤치프레스 40kg · 4세트',
    '덤벨 숄더프레스 10kg · 4세트',
    '랫풀다운 45kg · 4세트',
    '플랭크 60초 · 3세트',
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.fitness_center_rounded,
                size: 16,
                color: FigmaColors.primary,
              ),
              const SizedBox(width: 6),
              // 큰 글자 배율에서 제목이 카드를 넘겼다(#766).
              Flexible(
                child: Text(
                  l.exPtLogTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 칩 둘은 좁아지면 다음 줄로 넘긴다. 한 줄에 붙여 두면 320px 기본
          // 배율에서도 카드를 크게 넘겼고, 칩 글자를 줄이면 몇 회차인지·몇 시
          // 수업인지가 사라진다(#766).
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _MetaChip(
                icon: Icons.check_circle,
                text: '18:00 수업 완료',
                color: FigmaColors.statusGreen,
              ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    // 항목이 두 줄로 접히면 점이 가운데로 뜬다. 첫 줄 높이에
                    // 맞춰 위쪽에 고정한다.
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: FigmaColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 말줄임이 아니라 줄바꿈이다. `벤치프레스 40kg · 4세트` 가
                  // `벤치프레스 40k…` 가 되면 몇 세트인지가 사라진다 — 접혀도
                  // 뜻이 남아야 한다(#766).
                  Expanded(
                    child: Text(
                      it,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground,
                      ),
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
                    // 이름·라벨 묶음이 고정 폭이라 문구가 길어지면 줄이 그대로
                    // 넘쳤다. 한국어에서는 짧아 드러나지 않았고, 라벨을 번역
                    // 대상으로 옮기면서 영어(`Today's feedback`)에서 나타났다
                    // (#847, #766 과 같은 계열).
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // 가상의 트레이너 이름 — 실모드에서는 담당 트레이너의
                          // 실제 이름이 들어온다.
                          const Text(
                            '김트레이너',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                          Text(
                            l.exPtFeedbackTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '숄더프레스할 때 오른쪽 어깨가 들리는 경향이 있으니, 마무리할 때 '
                  '회전근개 스트레칭을 꼭 해주세요!',
                  style: TextStyle(
                    fontSize: 13.5,
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
          // 배율 1.6 이상에서는 칩 하나가 카드보다 넓어진다. 그때는 칩 안에서
          // 줄을 바꾼다 — 말줄임하면 몇 시 수업인지·몇 회차인지가 사라진다(#766).
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
