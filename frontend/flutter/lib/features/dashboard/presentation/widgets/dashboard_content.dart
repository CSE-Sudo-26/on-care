import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/charts/goal_line.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/motion.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/ai_advice_text.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_activity_status.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/trainer_chat_header_button.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/chart_semantics.dart';
import 'package:oncare/shared/widgets/coaching_sheet.dart';
import 'package:oncare/shared/widgets/metric_trend_chart.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// Home's own "/목표(단위)" suffix style. Same look as the shared
/// [kGoalSuffixStyle], one step larger so it scales with the rest of the Home
/// type; the other tabs keep the shared 9px size.
const TextStyle _kGoalSuffix = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.mutedForeground,
);

/// The Home tab, rebuilt to match the On-Care Figma redesign.
///
/// Sections (top → bottom): header, AI coaching banner, a 식단·영양 card
/// (칼로리·나트륨·당류 지표 카드 + 탄단지 + 선택한 지표의 주간 추이) and a
/// 운동 card (좌측 지표 3종 + 우측 주간 추이), 이번 주 AI 추천 식단 carousel,
/// 오늘의 일정. Per the product decision the 건강 지표 (심박수·수면) cards and
/// the sleep AI-coaching banner are omitted.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    this.onNotificationTap,
    this.onCalendarTap,
  });

  final VoidCallback? onNotificationTap;
  final VoidCallback? onCalendarTap;

  @override
  Widget build(BuildContext context) {
    return Center(
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
                    title: 'On - Care',
                    leading: const HeartLogo(),
                    trailingAction: const TrainerChatHeaderButton(),
                    onBell: onNotificationTap,
                    bellHasUnread:
                        (ref.watch(notificationUnreadProvider).valueOrNull ??
                            0) >
                        0,
                    onCalendar: onCalendarTap,
                  ),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                return ref
                    .watch(dashboardSummaryProvider)
                    .when(
                      loading: () => const _DashboardLoading(),
                      error: (Object error, StackTrace stackTrace) =>
                          _DashboardError(
                            onRetry: () =>
                                ref.invalidate(dashboardSummaryProvider),
                          ),
                      data: (DashboardSummary summary) => _DashboardData(
                        summary: summary,
                        // 홈 배너로 열어도 같은 시트다 — 배지도 같이 내려간다.
                        onCoachingTap: () =>
                            showCoachingSheet(context, ref: ref),
                        onDietTap: () => context.go(AppRoutes.diet),
                        onExerciseTap: () => context.go(AppRoutes.exercise),
                      ),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 80),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: <Widget>[
          Text(l.homeDashboardLoadError),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l.actionRetry)),
        ],
      ),
    );
  }
}

class _DashboardData extends StatelessWidget {
  const _DashboardData({
    required this.summary,
    required this.onCoachingTap,
    required this.onDietTap,
    required this.onExerciseTap,
  });

  final DashboardSummary summary;
  final VoidCallback onCoachingTap;
  final VoidCallback onDietTap;
  final VoidCallback onExerciseTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        if (summary.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              l.homeDashboardEmpty,
              style: const TextStyle(color: AppColors.foreground),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: _CoachingBanner(summary: summary, onTap: onCoachingTap),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: _DietNutritionCard(
            summary: summary,
            showCharts: !summary.isEmpty,
            onOpen: onDietTap,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: _ExerciseCard(
            summary: summary,
            showCharts: !summary.isEmpty,
            onOpen: onExerciseTap,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: _RecommendedMeals(),
        ),
        // 오늘의 일정은 지금 쓰지 않는다. 되살릴 수 있어 지우지 않고 남겨
        // 둔다. (#1055)
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        //   child: _ScheduleCard(items: summary.todaySchedule),
        // ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────── coaching banner ──

class _CoachingBanner extends StatelessWidget {
  const _CoachingBanner({required this.summary, required this.onTap});
  final DashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        // 플로팅 버튼을 감춘 동안(#862) AI 조언으로 들어가는 자리는 여기 하나다.
        key: const ValueKey<String>('home-coaching-banner'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          // AI 조언 배너만 원래의 연한 파랑 그라데이션을 유지한다(식단·운동
          // 카드는 흰색 + 회색 그림자).
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[FigmaColors.bannerStart, FigmaColors.bannerEnd],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: <Widget>[
                    const OniAvatar(size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l.homeAiAdviceTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            aiAdviceBody(l, summary),
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: FigmaColors.primaryA(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: FigmaColors.primary,
                      ),
                    ),
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

// ────────────────────────────────────────────────────── summary cards ──

/// Shared card chrome for the two Home summary cards: white fill, rounded
/// corners and the shared grey [kCardShadow]. No border, no top stripe.
class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// 홈 카드 헤더 — 제목 + AI 필 + 더보기 링크. 식단·운동 카드가 같은 구조라
/// 한 곳에 둔다.
///
/// 셋 다 고유 폭을 요구하고 `Spacer` 로 밀어내던 예전 구조는 **줄어들 수가
/// 없어서**, 폭이 모자라면 그대로 `RenderFlex overflowed` 를 냈다(#440).
/// 더보기 링크는 누를 것이라 항상 남기고, 제목·필이 남는 폭에 맞춰 줄어든다.
///
/// 발견 경로는 영어 로케일 위젯 테스트였는데, 그 환경의 기본 폰트는 라틴
/// 문자를 실제의 약 2배 폭으로 그린다. 즉 **실제 기기에서 잘려 보이던 것을
/// 확인하고 고친 것은 아니다.** 그래도 이 구조가 맞다 — 문구·폰트·폭 중 하나만
/// 달라져도 넘치던 것을, 넘치는 대신 줄어들게 바꾼 것이다.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.label, this.onOpen});

  final IconData icon;
  final String label;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    // `AI 분석` 필은 뗐다 (#1055). 홈의 요약은 대부분 AI 가 만든 것이라
    // 필이 카드를 갈라 주지 못하면서, 제목 줄만 좁혔다.
    return Row(
      children: <Widget>[
        Expanded(
          child: _CardTitle(icon: icon, label: label),
        ),
        const SizedBox(width: 8),
        _DetailLink(onTap: onOpen),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 배경 틴트 없이 아이콘만 둔다 (#1117) — 카드마다 붙은 사각 틴트가
        // 제목 줄을 무겁게 만들었다.
        Icon(icon, size: 18, color: FigmaColors.primary),
        const SizedBox(width: 6),
        // 폭이 모자라면 제목부터 줄인다 — 아이콘·필·더보기는 남긴다(#440).
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// 홈 식단·영양 카드에서 고른 지표(칼로리/나트륨/당류) — 탭을 벗어났다가 홈에
/// 다시 들어오면 기본값으로 되돌아가야 하는 임시 UI 상태라 Riverpod 에
/// 둔다(#861). 실제 요약 데이터(`dashboardSummaryProvider`)와는 분리된 값이다.
final _dashboardNutritionTabProvider = StateProvider<_NutTabKind>(
  (ref) => _NutTabKind.calories,
  name: 'dashboardNutritionTab',
);

/// 홈 탭 재진입 시 초기화할 임시 UI 상태 — 식단·영양 카드가 보여 주는 지표를
/// 기본값(칼로리)으로 되돌린다(#861).
void resetDashboardTransientUiState(WidgetRef ref) {
  ref.read(_dashboardNutritionTabProvider.notifier).state =
      _NutTabKind.calories;
}

// ───────────────────────────────────────────── diet + nutrition card ──
/// The merged 식단·영양 card: calorie ring + achievement, macro grams/goals,
/// and the weekly nutrition trend chart (legend + Y axis + point labels).
class _DietNutritionCard extends ConsumerWidget {
  const _DietNutritionCard({
    required this.summary,
    required this.showCharts,
    required this.onOpen,
  });
  final DashboardSummary summary;
  final bool showCharts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _NutTabKind tab = ref.watch(_dashboardNutritionTabProvider);
    final AppLocalizations l = AppLocalizations.of(context);
    final Map<_NutTabKind, _NutData> nutrition = _nutritionFor(summary);
    final _NutData cfg = nutrition[tab]!;
    final List<String> days = weekDayLabels(l);
    final int todayIdx = _todayIndex();
    final NumberFormat nf = NumberFormat('#,###');
    final String chartTitle = l.homeWeeklyMetricTrend(_nutLabel(l, tab));

    return _HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardHeader(
            icon: Icons.restaurant_rounded,
            label: l.homeDietNutritionTitle,
            onOpen: onOpen,
          ),
          const SizedBox(height: 14),
          // 상단: 칼로리·나트륨·당류를 큰 숫자 카드로 나란히. 탭하면 아래
          // 그래프가 그 지표의 주간 추이로 바뀐다.
          Row(
            children: <Widget>[
              for (final _NutTabKind kind in nutrition.keys) ...<Widget>[
                if (kind != nutrition.keys.first) const SizedBox(width: 8),
                Expanded(
                  child: _MetricStatCard(
                    label: _nutLabel(l, kind),
                    indicator: _indicatorFor(summary, kind),
                    selected: tab == kind,
                    onTap: () =>
                        ref
                                .read(_dashboardNutritionTabProvider.notifier)
                                .state =
                            kind,
                  ),
                ),
              ],
            ],
          ),
          if (showCharts) const SizedBox(height: 10),
          if (showCharts) const _SoftDivider(),
          if (showCharts) const SizedBox(height: 10),
          if (showCharts)
            Row(
              key: const ValueKey<String>('dashboard-nutrition-chart'),
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // 목표는 그래프의 목표선 라벨이 말한다 — 카드 위에 또
                      // 적으면 한 화면에서 같은 말이 두 번 나온다(#756).
                      _ChartLegend(title: chartTitle),
                      const SizedBox(height: 6),
                      MetricTrendChart(
                        values: cfg.cur,
                        dayLabels: days,
                        goal: cfg.goal,
                        ticks: cfg.ticks,
                        todayIndex: todayIdx,
                        // 지표를 바꾸면 선을 처음부터 다시 그려 값이 바뀐 것을
                        // 눈으로 따라가게 한다.
                        replayKey: tab,
                        // 화면 위 제목과 같은 문구로 시작한다 — 음성 안내에서도
                        // 이 그래프가 어느 지표의 것인지가 먼저 들린다.
                        semanticsLabel: chartSemanticsLabel(
                          l,
                          title: chartTitle,
                          points: chartSeriesPoints(
                            l,
                            values: cfg.cur,
                            dayLabels: days,
                            format: (double v) => '${nf.format(v)}${cfg.unit}',
                            // 선은 오늘까지만 잇는다. 아직 오지 않은 요일을
                            // 읽으면 화면에 없는 값을 말하게 된다.
                            upTo: todayIdx,
                          ),
                        ),
                        goalLabel: '${l.homeGoal}\n${nf.format(cfg.goal)}',
                        formatTick: nf.format,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 식단 카드 상단의 지표 카드 하나 — "칼로리" 라벨 + 큰 숫자 + "/2,000kcal"
/// 목표치 + 정상/초과 배지. 탭하면 아래 주간 추이 그래프가 이 지표로 바뀌고,
/// 선택된 카드만 브랜드 블루 테두리로 표시한다.
class _MetricStatCard extends StatelessWidget {
  const _MetricStatCard({
    required this.label,
    required this.indicator,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final HealthIndicator indicator;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool over =
        indicator.overBudget ||
        (indicator.max > 0 && indicator.current > indicator.max);
    // 선택 상태를 흰 배경·파란 테두리로만 알리면 스크린리더 사용자는 어떤
    // 지표가 켜져 있는지도, 이 카드가 누를 수 있는 요소인지도 알 수 없다.
    return Semantics(
      button: true,
      selected: selected,
      label: '$label (${indicator.unit})',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : FigmaColors.statBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? FigmaColors.primary : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Column(
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 초과는 배지가 아니라 수치 자체를 빨갛게 해서 말한다. 배지는
              // 카드마다 있고 없고가 갈려 카드 높이를 들쭉날쭉하게 만들었다
              // (#1070). 색은 어느 카드에도 자리를 더 먹지 않는다.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _metricNumber(indicator.current),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: over ? FigmaColors.dangerRed : FigmaColors.ink,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // 목표치는 회색 작은 글씨로 현재 수치 바로 아래. 단위는 라벨이
              // 아니라 목표치 오른쪽에 붙인다("/2,000kcal") — 라벨에 두면
              // "칼로리 (kcal)" 처럼 길어져 좁은 카드에서 먼저 줄어들었다.
              // 목표가 없는 지표(max=0)면 단위만 남겨 큰 숫자가 단위를 잃지
              // 않게 한다.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  indicator.max > 0
                      ? '/${_metricNumber(indicator.max)}${indicator.unit}'
                      : indicator.unit,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
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

// ─────────────────────────────────────────────────── shared card chrome ──

/// The "자세히 >" trailing link used in the card headers.
class _DetailLink extends StatelessWidget {
  const _DetailLink({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // `GestureDetector` 는 눌러도 버튼으로 인식되지 않는다 — 문구는 읽히지만
    // 누를 수 있는 자리라는 사실이 빠진다(#972).
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l.homeDetails,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: FigmaColors.primary,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 14,
              color: FigmaColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline divider used to separate the sub-sections inside a card.
class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: FigmaColors.primaryA(0.07));
  }
}

/// A tiny right-aligned chart Y-axis value label.
/// 이번 주의 시작(월요일). 운동 탭과 같은 기준으로 잘라야 홈이 같은 한 주를
/// 말한다.
DateTime _thisMonday() {
  final DateTime n = nowKst();
  final DateTime d = DateTime(n.year, n.month, n.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// 유형별 아이콘. 라벨·색은 운동 탭(`kindLabel`/`kindColor`)과 공유한다.
IconData _kindIcon(ExerciseLoadKind kind) => switch (kind) {
  ExerciseLoadKind.cardio => Icons.directions_run_rounded,
  ExerciseLoadKind.strength => Icons.fitness_center_rounded,
  ExerciseLoadKind.flexibility => Icons.self_improvement_rounded,
};

/// 유형의 **원래 단위** — 유산소·스트레칭은 분, 근력은 세트.
String _kindUnit(AppLocalizations l, ExerciseLoadKind kind) => switch (kind) {
  ExerciseLoadKind.cardio || ExerciseLoadKind.flexibility => l.unitMinutes,
  ExerciseLoadKind.strength => l.unitSets,
};

/// The full-width 운동 card: activity metrics (time / kcal / count), the burn
/// goal progress, and a weekly burned-calories trend chart with value labels.
class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.summary,
    required this.showCharts,
    required this.onOpen,
  });
  final DashboardSummary summary;
  final bool showCharts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 운동 탭과 같은 단일 소스(exerciseWeekViewProvider)에서 주간 수치·일별
    // 칼로리를 읽어 홈 카드와 운동 탭이 항상 일치한다. 이 provider 는 오늘 체크한
    // AI 추천 운동까지 이미 더한 값이라, 지표와 주간 추이 차트가 같이 움직인다.
    final AsyncValue<ExerciseWeek> weekAsync = ref.watch(
      exerciseWeekViewProvider,
    );
    // 새로고침 중에는 직전 값을 계속 그린다 — 이미 맞는 그림을 지웠다 다시
    // 그리면 깜빡임만 는다.
    final ExerciseWeek? wk = weekAsync.valueOrNull;
    // 지표는 운동 탭 `운동 현황 - 이번 주` 와 **같은 네 가지**다 (#1119).
    // 예전에는 활동 시간·소모 칼로리·운동 일수를 MY 프로필 목표(주 3회·150분·
    // 500kcal)와 견줬는데, 운동 탭은 유형별 주간 목표(ExerciseLoadGoals)를 쓰고
    // 있어 같은 한 주를 두 화면이 다르게 말했다.
    const ExerciseLoadGoals goals = kDefaultExerciseLoadGoals;
    final List<ExerciseDayLoad> loads = wk == null
        ? const <ExerciseDayLoad>[]
        : dayLoadsOfWeek(wk, _thisMonday());
    double sumOf(ExerciseLoadKind k) => loads.fold<double>(
      0,
      (double a, ExerciseDayLoad d) => a + d.valueOf(k),
    );
    final double burned = wk == null
        ? summary.exerciseCalories.toDouble()
        : loads.fold<double>(
            0,
            (double a, ExerciseDayLoad d) => a + d.calories,
          );
    // 오늘 요일(0=월 … 6=일). 오늘 이후(미래) 요일은 아직 운동 전이므로 0 으로
    // 두고, '오늘' 강조도 실제 오늘 요일에 붙인다.
    final int todayIdx = nowKst().weekday - 1;
    final NumberFormat nf = NumberFormat('#,###');

    return _HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardHeader(
            icon: Icons.fitness_center_rounded,
            label: l.dashboardMetricExercise,
            onOpen: onOpen,
          ),
          const SizedBox(height: 14),
          // 지표 3개는 왼쪽에 세로로, 주간 추이 그래프는 오른쪽에 나란히 둔다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ExerciseStat(
                      icon: Icons.local_fire_department_rounded,
                      label: l.homeExerciseBurned,
                      value: nf.format(burned),
                      goal: nf.format(goals.weeklyBurnKcal),
                      unit: l.unitKcal,
                    ),
                    for (final ExerciseLoadKind k
                        in ExerciseLoadKind.values) ...<Widget>[
                      const SizedBox(height: 10),
                      _ExerciseStat(
                        icon: _kindIcon(k),
                        label: kindLabel(l, k),
                        value: nf.format(sumOf(k).round()),
                        goal: nf.format(goals.weeklyGoalOf(k).round()),
                        unit: _kindUnit(l, k),
                      ),
                    ],
                  ],
                ),
              ),
              if (showCharts) const SizedBox(width: 20),
              if (showCharts)
                Expanded(
                  flex: 6,
                  child: _ExerciseTrend(
                    weekAsync: weekAsync,
                    todayIndex: todayIdx,
                    // 하루 목표. 운동 탭이 요일 막대에 긋는 것과 같은 선이다
                    // (#1119) — 식단 그래프가 하루 목표를 그리는 것과 같은 뜻.
                    dailyGoalCalories: goals.dailyBurnKcal,
                    // 되짚는 대상은 파생 provider 가 아니라 실제로 서버를
                    // 부르는 쪽이다 — 뷰만 무효화하면 캐시된 에러가 그대로
                    // 다시 계산돼 아무 일도 일어나지 않는다.
                    onRetry: () => ref.invalidate(exerciseWeekProvider),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 운동 카드 오른쪽의 주간 추이. 상태를 세 갈래로 나눈다 — 값이 있으면 그리고,
/// 실패했으면 실패했다고 말하고, 아직이면 자리만 잡는다.
///
/// 예전에는 값이 없을 때 데모 상수(월 300 · 화 420 …)를 그렸다. `valueOrNull`
/// 은 로딩과 에러를 똑같이 `null` 로 주므로 그 폴백은 첫 프레임이 아니라
/// **요청이 실패한 동안 계속** 걸렸고, 운동 기록이 하나도 없는 회원의 홈에
/// 오류 표시 하나 없이 "이만큼 태웠다" 는 막대가 남았다. 왼쪽 3지표는 서버가
/// 준 주간 합계로 폴백하니, 지표와 그래프가 서로 다른 이야기를 했다(#962).
class _ExerciseTrend extends StatelessWidget {
  const _ExerciseTrend({
    required this.weekAsync,
    required this.todayIndex,
    required this.dailyGoalCalories,
    required this.onRetry,
  });

  final AsyncValue<ExerciseWeek> weekAsync;

  /// 하루 목표 소모 칼로리 — 주간 목표 ÷ 7. (#1015)
  final double dailyGoalCalories;

  /// 오늘 요일(0=월 … 6=일).
  final int todayIndex;
  final VoidCallback onRetry;

  /// 차트가 차지하는 높이. 세 상태가 같은 높이를 써야 로딩에서 데이터로 바뀔 때
  /// 카드가 튀지 않는다.
  static const double _chartHeight = 96;

  /// 서버가 준 일별 칼로리를 일곱 칸으로 맞춘다. 모자라는 칸은 0 이고, 아직
  /// 오지 않은 요일도 0 이다.
  static List<double> series(List<double> daily, int todayIndex) {
    return <double>[
      for (int i = 0; i < 7; i++)
        if (i > todayIndex || i >= daily.length) 0 else daily[i],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ExerciseWeek? wk = weekAsync.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${l.homeWeeklyExerciseTrend} (${l.unitKcal})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        if (wk != null)
          _chart(context, l, wk)
        else if (weekAsync.hasError)
          _unavailable(l)
        else
          _placeholder(),
      ],
    );
  }

  Widget _chart(BuildContext context, AppLocalizations l, ExerciseWeek wk) {
    final List<double> week = series(wk.dailyCalories, todayIndex);
    final (double lo, double hi) = _barScale(week);
    final List<String> days = weekDayLabels(l);
    // 막대와 요일 라벨은 한 덩어리로 읽는다 — 낱개로는 `월` `화` 뿐이라
    // 얼마나 태웠는지가 음성 안내에서 사라진다(#972).
    return Semantics(
      container: true,
      label: chartSemanticsLabel(
        l,
        title: '${l.homeWeeklyExerciseTrend} (${l.unitKcal})',
        points: chartSeriesPoints(
          l,
          values: week,
          dayLabels: days,
          format: (double v) => '${v.round()}${l.unitKcal}',
          // 아직 오지 않은 요일은 0 으로 채워져 있다. 그 자리를 읽으면
          // 그리지도 않은 막대를 말하게 된다.
          upTo: todayIndex,
        ),
      ),
      child: ExcludeSemantics(
        // 목표치는 왼쪽 칸에 두 줄로 적는다 — 홈 탭 식단 영양 그래프와 같은
        // 자리다 (#1071). 요일 라벨도 같은 만큼 밀려야 막대와 줄이 맞는다.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ChartGoalAxis(
              height: _chartHeight,
              label:
                  '${l.homeGoal}\n'
                  '${NumberFormat('#,###').format(dailyGoalCalories.round())}',
              lineBottom: dailyGoalCalories > lo && dailyGoalCalories < hi
                  ? ((dailyGoalCalories - lo) /
                            ((hi - lo) <= 0 ? 1 : (hi - lo))) *
                        (_chartHeight - kExerciseBarLabelGap)
                  : null,
            ),
            const SizedBox(width: chartGoalAxisGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    key: const ValueKey<String>('dashboard-exercise-chart'),
                    height: _chartHeight,
                    child: ChartReveal(
                      duration: AppMotion.chartGrow,
                      // 막대마다 시작 시점을 어긋나게 하므로(chartStagger)
                      // 마스터 진행도는 선형으로 받는다.
                      curve: Curves.linear,
                      builder: (BuildContext context, double t) => CustomPaint(
                        size: Size.infinite,
                        painter: _ExerciseBarPainter(
                          data: week,
                          lo: lo,
                          hi: hi,
                          todayIndex: todayIndex,
                          color: FigmaColors.primary,
                          goal: dailyGoalCalories,
                          progress: t,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < days.length; i++)
                        Expanded(
                          child: Center(
                            // 식단 영양 카드와 동일하게, 오늘은 #3EAFDF
                            // 원형 안에 흰색 요일 글씨로 표기한다.
                            child: i == todayIndex
                                ? Container(
                                    width: 18,
                                    height: 18,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: FigmaColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      days[i],
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    days[i],
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 불러오지 못했을 때. 값을 지어내는 대신 못 불러왔다고 적고, 다시 시도할
  /// 자리를 준다.
  Widget _unavailable(AppLocalizations l) {
    return SizedBox(
      key: const ValueKey<String>('dashboard-exercise-chart-error'),
      height: _chartHeight + 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.homeExerciseTrendUnavailable,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const ValueKey<String>('dashboard-exercise-chart-retry'),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l.actionRetry,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: FigmaColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 아직 읽는 중. 자리만 잡아 두면 값이 도착했을 때 카드가 튀지 않는다.
  Widget _placeholder() {
    return Container(
      key: const ValueKey<String>('dashboard-exercise-chart-loading'),
      height: _chartHeight + 24,
      decoration: BoxDecoration(
        color: FigmaColors.primaryA(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/// [_ExerciseTrend.series] 를 테스트에서 부르기 위한 창구. 일곱 칸 정규화는
/// 위젯을 띄우지 않고도 못박아 두고 싶은 규칙이다.
@visibleForTesting
List<double> exerciseTrendSeriesForTest(List<double> daily, int todayIndex) =>
    _ExerciseTrend.series(daily, todayIndex);

/// One activity metric in the 운동 card's left column: a blue icon chip with
/// its label on the first line and the value underneath, per the Home layout
/// reference. No tile chrome — the card itself is the surface.
class _ExerciseStat extends StatelessWidget {
  const _ExerciseStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.goal,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  /// Optional small "/목표" suffix shown after the value (e.g. "/150분").
  final String? goal;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: FigmaColors.iconTint,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: FigmaColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.ink,
                          letterSpacing: -0.3,
                          height: 1,
                        ),
                      ),
                      if (goal != null)
                        Text(' /$goal$unit', maxLines: 1, style: _kGoalSuffix)
                      else
                        Text(
                          ' $unit',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Padded min/max scale for the nutrition line chart. Deliberately excludes a
/// zero baseline so day-to-day variation reads as a dynamic slope rather than
/// 목표 대비 상태색: 초과(빨강) / 그 외(브랜드 파랑).
///
/// 지표 카드의 초과 표시와 같은 두 색(dangerRed/statusWithinGoal)만 쓴다 —
/// 카드는 2단계인데 그래프만 근접(주황) 3단계라, 초과가 아닌 날의 점이
/// 주황으로 찍혀 서로 다른 이야기를 했다. 이제 점은
/// Padded scale for the exercise bar chart. The baseline sits well below the
/// smallest bar so the difference between days is visually pronounced.
(double, double) _barScale(List<double> d) {
  final double hi = d.reduce(math.max);
  // 0을 기준선으로 삼아 값이 0인 날은 막대가 0에 가깝게, 위쪽에 여유를 둬
  // 막대가 카드 높이를 꽉 채우지 않도록 한다.
  return (0, hi <= 0 ? 1 : hi * 1.3);
}

// ───────────────────────────────────────────────────── nutrition data ──

class _NutData {
  const _NutData({
    required this.cur,
    required this.unit,
    required this.goal,
    required this.ticks,
    required this.color,
    required this.warn,
  });
  final List<double> cur;
  final String unit;
  final double goal;

  /// 세로축(가로 눈금선) 값들. 지표마다 다르게 지정한다.
  final List<double> ticks;
  final Color color;
  final bool warn;
}

/// Stable identity for a nutrition tab, decoupled from its displayed label
/// so the shown language never becomes an internal key.
enum _NutTabKind { calories, sodium, sugar }

/// 지표마다 고정된 표시 규칙 — 단위·눈금·색. 값은 여기 없다.
///
/// 예전에는 이 자리에 주간 이력 예시 숫자까지 함께 들어 있었고, 응답이 7일을
/// 채우지 않으면 그 숫자가 그대로 그려졌다. 화면에 뜬 한 주가 회원의 것이
/// 아닐 수 있다는 뜻이라, 표시 규칙만 남기고 값은 응답에서만 온다(#962).
const Map<_NutTabKind, _NutStyle> _nutStyles = <_NutTabKind, _NutStyle>{
  _NutTabKind.calories: _NutStyle(
    unit: 'kcal',
    // 맨 아래 0 눈금은 당류 그래프와 같은 기준선 역할이라 항상 넣는다 —
    // 세 지표가 한 카드에서 탭으로 바뀌는데 축의 바닥이 서로 달랐다 (#548).
    // 그 위 눈금은 2개만 둔다. 라벨 칸은 16px 인데 촘촘히(1000·1500·2000·2500)
    // 놓으면 칸 간격이 16px 을 밑돌아 아래쪽 라벨끼리 겹쳐 숫자를 읽을 수
    // 없었다. 목표선은 따로 그리지 않으므로(상단 '목표 N' 라벨과 데이터
    // 포인트 상태색으로만 표현) 2000 을 빼도 잃는 정보가 없다.
    ticks: <double>[0, 1500, 2500],
    color: FigmaColors.primary,
  ),
  _NutTabKind.sodium: _NutStyle(
    unit: 'mg',
    ticks: <double>[0, 1750, 3500],
    color: FigmaColors.orange,
  ),
  _NutTabKind.sugar: _NutStyle(
    unit: 'g',
    ticks: <double>[0, 25, 50],
    color: FigmaColors.sugarPurple,
  ),
};

class _NutStyle {
  const _NutStyle({
    required this.unit,
    required this.ticks,
    required this.color,
  });
  final String unit;
  final List<double> ticks;
  final Color color;
}

Map<_NutTabKind, _NutData> _nutritionFor(DashboardSummary summary) {
  final liveValues = <_NutTabKind, HealthIndicator>{
    _NutTabKind.calories: summary.calorieIndicator,
    _NutTabKind.sodium: summary.sodiumIndicator,
    _NutTabKind.sugar: summary.sugarIndicator,
  };
  final List<NutritionDay>? week = summary.nutritionWeek.length == 7
      ? summary.nutritionWeek
      : null;
  // 주간 이력이 없으면 오늘 값만 제 요일 자리에 놓고 나머지는 비운다 —
  // 없는 기록을 지어내지 않는다.
  final int todayIdx = _todayIndex();
  return <_NutTabKind, _NutData>{
    for (final entry in _nutStyles.entries)
      entry.key: _NutData(
        cur: week != null
            ? <double>[
                for (final day in week)
                  switch (entry.key) {
                    _NutTabKind.calories => day.calories.toDouble(),
                    _NutTabKind.sodium => day.sodiumMg.toDouble(),
                    _NutTabKind.sugar => day.sugarG,
                  },
              ]
            : <double>[
                for (int i = 0; i < 7; i++)
                  i == todayIdx ? liveValues[entry.key]!.current.toDouble() : 0,
              ],
        unit: entry.value.unit,
        goal: liveValues[entry.key]!.max.toDouble(),
        ticks: entry.value.ticks,
        color: entry.value.color,
        warn: liveValues[entry.key]!.overBudget,
      ),
  };
}

/// 오늘 요일 인덱스(0=월 … 6=일). 고정 라벨 배열 `_weekDayLabels` 와 함께 써서
/// 주간 차트의 '오늘' 배지·라이브 값을 실제 요일 칸에 배치하고, 오늘 이후(미래)
/// 요일의 0값이 급락처럼 보이지 않도록 렌더 범위를 오늘까지로 제한한다.
/// 홈 카드 전체가 이 하나만 쓴다(지표 카드·차트 기준이 어긋나지 않도록).
int _todayIndex() => nowKst().weekday - 1;

/// 지표 키 → 화면 라벨(칼로리/나트륨/당류).
String _nutLabel(AppLocalizations l, _NutTabKind key) => switch (key) {
  _NutTabKind.calories => l.dashboardMetricCalories,
  _NutTabKind.sodium => l.dietSodium,
  _NutTabKind.sugar => l.dietSugar,
};

/// 지표 수치 표기. 정수는 천단위 콤마만 붙이고, 소수가 있으면 한 자리까지
/// 남긴다(당류 17.8 이 18 로 반올림돼 지표 카드와 그래프 라벨·식단 탭 수치가
/// 서로 어긋나던 문제).
String _metricNumber(num v) => v == v.roundToDouble()
    ? NumberFormat('#,###').format(v)
    : NumberFormat('#,##0.#').format(v);

/// 지표 키 → 오늘 수치(현재값·목표·초과 여부).
HealthIndicator _indicatorFor(DashboardSummary s, _NutTabKind key) =>
    switch (key) {
      _NutTabKind.calories => s.calorieIndicator,
      _NutTabKind.sodium => s.sodiumIndicator,
      _NutTabKind.sugar => s.sugarIndicator,
    };

// 이번 주 꺾은선(연회색). 선은 배경처럼 물러나고 데이터 포인트(상태색)와 값
// 라벨이 읽히도록 눈금선보다 아주 조금만 진하게 잡는다.

/// The weekly nutrition trend line: a solid current-week line, solid
/// horizontal tick gridlines (uniform weight), and value labels on each
/// point. The goal is shown via the top label + point status colors, not a
/// separate line. The [lo]/[hi] scale is padded away from zero so the line
/// reads as a dynamic slope rather than a flat trace.
/// The weekly exercise bar chart. Bars sit on a [lo]/[hi] scale whose baseline
/// is pushed below the smallest value so day-to-day variation is pronounced;
/// each bar carries its kcal value label, and today's bar is highlighted.
/// 막대 꼭대기의 값 라벨이 차지하는 위쪽 여백. 목표선 높이 계산도 이 값을
/// 빼야 왼쪽 칸의 목표치가 선과 같은 높이에 앉는다.
const double kExerciseBarLabelGap = 20;

class _ExerciseBarPainter extends CustomPainter {
  _ExerciseBarPainter({
    required this.data,
    required this.lo,
    required this.hi,
    required this.todayIndex,
    required this.color,
    required this.goal,
    this.progress = 1,
  });

  final List<double> data;
  final double lo;
  final double hi;

  /// 오늘 요일 인덱스(0=월 … 6=일). 마지막 막대 고정이 아니라 이 막대를 강조한다.
  final int todayIndex;
  final Color color;

  /// 하루 목표 소모 칼로리. 가로선은 이 목표선 하나뿐이다 (#1015).
  final double goal;

  /// 0 → 1 진입 애니메이션 진행도(선형). 막대는 월요일부터 차례로 바닥에서
  /// 자라 오르고, 값 라벨은 해당 막대와 함께 페이드인한다.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double span = (hi - lo) <= 0 ? 1 : (hi - lo);
    final int n = data.length;
    final double slot = w / n;
    final double barW = math.min(slot * 0.5, 22);
    const double labelGap = kExerciseBarLabelGap;

    // 가로선은 목표선 하나다 (#1015). 바닥에 긋던 축선은 지운다 — 막대가
    // 이미 바닥을 그리고, 두 선이 같은 굵기라 어느 쪽이 목표인지 헷갈렸다.
    final double span2 = span;
    final double goalY = h - ((goal - lo) / span2) * (h - labelGap);
    // 목표치는 그래프 왼쪽 칸(`ChartGoalAxis`)이 적는다 — 선 위 오른쪽 끝에
    // 얹던 시절에는 목표에 가까운 막대의 꼭대기와 겹쳤다. (#1071)
    if (goal > lo && goal < hi) {
      ChartGoalLine.paint(canvas, y: goalY, left: 0, right: w);
    }

    for (int i = 0; i < n; i++) {
      final double v = data[i];
      // 막대별 진행도. 높이와 라벨 투명도를 같이 몰아 올리면 막대가
      // 자라면서 값이 따라 붙는 것처럼 보인다.
      final double t = chartStagger(progress, i, n);
      final double bh = ((v - lo) / span) * (h - labelGap) * t;
      final double cx = slot * i + slot / 2;
      final double top = h - bh;
      final bool today = i == todayIndex;
      final Color c = today ? color : color.withValues(alpha: 0.30);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, top, barW, bh),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        Paint()..color = c,
      );
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: NumberFormat('#,###').format(v),
          style: TextStyle(
            // 막대 위 숫자는 막대보다 작아야 한다 — 그래프는 흐름을 보는
            // 자리고, 정확한 값은 상세에서 읽는다. (#1055)
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: (today ? color : const Color(0xFF9AA6B2)).withValues(
              alpha: t,
            ),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final double lx = (cx - tp.width / 2).clamp(0.0, w - tp.width);
      final double ly = math.max(0, top - tp.height - 3);
      tp.paint(canvas, Offset(lx, ly));
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseBarPainter old) =>
      old.data != data ||
      old.lo != lo ||
      old.hi != hi ||
      old.todayIndex != todayIndex ||
      old.color != color ||
      old.progress != progress;
}

// ───────────────────────────────────────────────────── recommended meals ──

/// 추천을 누가 골랐는지. 트레이너가 짚어 준 식단과 AI 가 고른 식단은 회원이
/// 받아들이는 무게가 다르다 — 카드에 적어 둔다. (#1056)
enum _RecSource { trainer, ai }

class _RecMeal {
  const _RecMeal(
    this.photo,
    this.emoji,
    this.name,
    this.reason,
    this.bg,
    this.tag, {
    this.source = _RecSource.ai,
  });

  /// Bundled dish photo shown on the card. [emoji] over [bg] is the fallback
  /// when the asset is missing, so the section still renders end-to-end.
  final String photo;
  final String emoji;
  final String name;
  final String reason;
  final Color bg;

  /// 영양 특성 배지. 어휘는 여섯 가지로 고정한다 — 같은 뜻을 화면마다 다른
  /// 말로 부르지 않기 위해서다. (#1056)
  final String tag;

  final _RecSource source;

  /// 사진·태그는 그대로 두고 추천 이유 문구만 바꾼 사본.
  /// 서버가 개인화 문구를 보냈을 때 쓴다.
  _RecMeal withReason(String newReason) =>
      _RecMeal(photo, emoji, name, newReason, bg, tag, source: source);

  /// 출처만 바꾼 사본.
  _RecMeal withSource(_RecSource newSource) =>
      _RecMeal(photo, emoji, name, reason, bg, tag, source: newSource);
}

/// 서버 카탈로그 key → 화면 표시(사진·이모지·문구·색).
///
/// 추천 API 는 무엇을 어떤 순서로 보여줄지(`key`)만 정하고, 실제 그리기는 여기서
/// 한다. 사진은 앱 번들 에셋이고 문구는 로케일별 ARB 라, 서버가 문자열을 만들면
/// 영어 화면에 한국어가 섞이고 사진 없는 요리가 나오기 때문이다.
/// key 값은 백엔드 `app/data/meal_catalog.py` 와 일치해야 한다.
Map<String, _RecMeal> _recMealsByKey(AppLocalizations l) => <String, _RecMeal>{
  'chicken_salad': _RecMeal(
    'assets/images/rec-chicken-salad.jpg',
    '🥗',
    l.homeMealChickenSalad,
    l.homeMealReasonSodium,
    const Color(0xFFE8F5E9),
    l.homeMealTagLowSodium,
  ),
  'brown_rice_box': _RecMeal(
    'assets/images/rec-brown-rice-box.jpg',
    '🍱',
    l.homeMealBrownRiceBox,
    l.homeMealReasonGlucose,
    const Color(0xFFFFF8E1),
    // 혈당을 가리키던 `저GI` 는 이 앱이 다른 곳에서 쓰지 않는 말이었다.
    l.homeMealTagLowSugar,
  ),
  'salmon': _RecMeal(
    'assets/images/rec-salmon-steak.jpg',
    '🐟',
    l.homeMealSalmon,
    l.homeMealReasonOmega,
    const Color(0xFFE3F2FD),
    l.homeMealTagHighProtein,
  ),
  'tofu': _RecMeal(
    'assets/images/rec-tofu-broccoli.png',
    '🥦',
    l.homeMealTofu,
    l.homeMealReasonLowCal,
    const Color(0xFFF3E5F5),
    l.homeMealTagLowCal,
  ),
  'namul_bibimbap': _RecMeal(
    'assets/images/rec-namul-bibimbap.png',
    '🥬',
    l.homeMealNamulBibimbap,
    l.homeMealReasonFiber,
    const Color(0xFFEFF7ED),
    // 나물 위주라 지방이 적다 — `고식이섬유` 는 정해 둔 여섯 어휘 밖이다.
    l.homeMealTagLowFat,
  ),
};

/// 이유 코드 → 기본 문구. 서버가 개인화 문구(`reasonText`)를 주지 않았을 때 쓴다.
/// 요리별 기본 이유는 카탈로그에 고정돼 있어, 이 경로면 화면이 서버 연동 이전과
/// 완전히 같아진다.
String? _reasonTextFor(AppLocalizations l, String reasonKey) =>
    switch (reasonKey) {
      'sodium' => l.homeMealReasonSodium,
      'glucose' => l.homeMealReasonGlucose,
      'omega' => l.homeMealReasonOmega,
      'low_cal' => l.homeMealReasonLowCal,
      'fiber' => l.homeMealReasonFiber,
      _ => null,
    };

/// 개인화 근거 한 줄 — 예: "최근 3일 평균 나트륨 2,400mg · 권장 초과".
///
/// 서버가 준 `basis` 문자열을 쓰지 않고 수치로 다시 만든다. `basis` 는 서버가 조립한
/// 한국어라 영어 로케일에 그대로 쓰면 문구가 섞인다(요리명·이유를 key 로 주고받는
/// 것과 같은 이유).
///
/// 개인화되지 않았거나 근거 데이터가 없으면 null — 목업/데모 모드와 신규 가입자가
/// 이 경로라, 화면에 아무것도 추가되지 않는다.
String? _basisTextFor(AppLocalizations l, MealRecommendations recs) {
  if (!recs.personalized || recs.daysWithData <= 0 || recs.avgSodiumMg <= 0) {
    return null;
  }
  final String sodium = NumberFormat.decimalPattern().format(recs.avgSodiumMg);
  final String base = l.homeRecBasisSodium(recs.daysWithData, sodium);
  return recs.sodiumOverLimit ? '$base · ${l.homeRecBasisOverLimit}' : base;
}

/// 추천 응답 → 카드 목록.
///
/// 앱이 모르는 key(서버 카탈로그가 먼저 늘어난 경우)는 그릴 방법이 없으므로
/// 조용히 버리고, 그만큼을 기본 순서에서 채워 카드 수를 유지한다.
List<_RecMeal> _cardsFor(AppLocalizations l, MealRecommendations recs) {
  final Map<String, _RecMeal> byKey = _recMealsByKey(l);
  final List<_RecMeal> cards = <_RecMeal>[];
  final Set<String> used = <String>{};

  for (final MealRecommendation rec in recs.items) {
    final _RecMeal? base = byKey[rec.key];
    if (base == null || used.contains(rec.key)) continue;
    used.add(rec.key);
    final String reason =
        rec.reasonText ?? _reasonTextFor(l, rec.reasonKey) ?? base.reason;
    cards.add(base.withReason(reason));
  }

  for (final String key in kDefaultMealKeys) {
    if (cards.length >= kDefaultMealKeys.length) break;
    if (used.contains(key)) continue;
    used.add(key);
    final _RecMeal? base = byKey[key];
    if (base != null) cards.add(base);
  }
  return cards;
}

class _RecommendedMeals extends ConsumerWidget {
  const _RecommendedMeals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    // valueOrNull 이라 로딩·에러에서 기본 추천이 그대로 그려진다. 스켈레톤을 두면
    // 홈 진입 때 카드가 한 번 비었다가 채워져 화면이 깜빡인다(목업 모드에서는
    // 결과가 기본값과 같아 아예 아무 변화도 보이지 않는다).
    final MealRecommendations recs =
        ref.watch(dietRecommendationsProvider).valueOrNull ??
        MealRecommendations.fallback;
    // 담당 트레이너가 있는 회원의 첫 장은 트레이너가 짚어 준 자리다. 담당이
    // 없으면 그 배지를 달지 않는다 — 없는 사람의 추천이라고 말하게 된다.
    final bool hasCoach = ref.watch(memberCoachProvider).valueOrNull != null;
    final List<_RecMeal> meals = <_RecMeal>[
      for (final (int i, _RecMeal meal) in _cardsFor(l, recs).indexed)
        i == 0 && hasCoach ? meal.withSource(_RecSource.trainer) : meal,
    ];
    // 개인화된 응답일 때만 근거를 보여준다. 목업/데모 모드와 신규 가입자는
    // personalized=false 라 이 줄이 아예 나타나지 않는다(화면 불변).
    final String? basis = _basisTextFor(l, recs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    Text(
                      l.homeRecMealsTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.ink,
                      ),
                    ),
                    if (basis != null)
                      Text(
                        basis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: FigmaColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 카드 높이를 숫자로 박지 않는다 (#1118). 예전에는 설명 두 줄을 미리
        // 잡아 두느라, 설명이 한 줄인 카드는 태그 아래가 통째로 비었다.
        // IntrinsicHeight 가 실제 내용으로 높이를 재고, 카드끼리는 가장 높은
        // 것에 맞춰 늘어난다 — 글씨 배율이 커져도 계산이 어긋날 자리가 없다.
        //
        // 아래 여백(18)은 카드 그림자(blur 14, y+4)가 뷰포트에 잘리지 않을
        // 만큼이다. 위(8)보다 넉넉한 것은 그림자가 아래로 치우쳐 지기 때문.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < meals.length; i++) ...<Widget>[
                  if (i != 0) const SizedBox(width: 12),
                  _RecMealCard(meal: meals[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 카드 좌측 상단의 추천 출처 배지.
class _RecSourceBadge extends StatelessWidget {
  const _RecSourceBadge({required this.source});

  final _RecSource source;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool trainer = source == _RecSource.trainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        // 사진 위에 얹히므로 배경은 불투명해야 글자가 읽힌다.
        color: trainer ? FigmaColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: trainer ? FigmaColors.primary : FigmaColors.hairline,
        ),
      ),
      child: Text(
        trainer ? l.homeMealSourceTrainer : l.homeMealSourceAi,
        key: const Key('rec-meal-source'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: trainer ? Colors.white : FigmaColors.primary,
        ),
      ),
    );
  }
}

class _RecMealCard extends StatelessWidget {
  const _RecMealCard({required this.meal});
  final _RecMeal meal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Image.asset(
                meal.photo,
                height: 72,
                width: double.infinity,
                fit: BoxFit.cover,
                // Fall back to the emoji tile if the bundled photo is missing.
                errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                    _emojiHeader(),
              ),
              // 누가 고른 추천인지 사진 위에 얹는다 — 카드가 130px 로 좁아
              // 아래 글자 자리를 더 쓰면 이름이나 이유가 밀린다. (#1056)
              Positioned(
                left: 6,
                top: 6,
                child: _RecSourceBadge(source: meal.source),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  meal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                // 카드 폭이 130px 고정이라 12.5px 로는 "나트륨 조절에
                // 좋아요" 가 한 줄에 못 들어간다. 가독성 개선(3299f996)에서
                // 키운 값을 이 카드만 되돌린다 — 제목이 진한 14px 이라 부제는
                // 작은 회색이어야 위계도 산다.
                Text(
                  meal.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    // 배지 색은 하나다 (#1056). 요리마다 색이 달라지면 색이
                    // 영양 특성을 뜻하는지 요리 종류를 뜻하는지 알 수 없다.
                    color: FigmaColors.primaryA(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    meal.tag,
                    key: const Key('rec-meal-tag'),
                    // 영어 태그는 길어서 두 줄이 되고, 그만큼 설명이 눌려
                    // 사라진다 — 태그는 한 줄로 못 박는다. (#1004)
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: FigmaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiHeader() => Container(
    height: 72,
    width: double.infinity,
    color: meal.bg,
    alignment: Alignment.center,
    child: Text(meal.emoji, style: const TextStyle(fontSize: 36)),
  );
}

// ───────────────────────────────────────────────────────── schedule ──

/// 홈 하단의 오늘 일정 카드. 지금은 화면에 걸지 않았다 (#1055) — 지우지 않고
/// 남겨 둔 것이라 쓰이지 않는다는 경고를 여기서 끈다.
// ignore: unused_element
class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.items});

  final List<ScheduleItem> items;

  /// 트레이너가 잡아 준 오늘의 PT 를 일정 항목으로 바꾼다. (#490)
  ///
  /// 별도 카드를 만들지 않고 여기 합치는 이유: 회원 입장에서 '오늘 뭐 하지'는
  /// 하나의 질문이다. PT 만 따로 떼면 같은 시간대를 두 곳에서 봐야 한다.
  ///
  /// 데모는 담당 일정이 없어(`MockMemberCoachRepository.fetchSessions`) 빈
  /// 목록이 오므로 카드가 지금과 똑같이 그려진다.
  static List<ScheduleItem> _todaysSessions(List<CoachSession> sessions) {
    final DateTime now = nowKst();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return <ScheduleItem>[
      for (final CoachSession session in sessions)
        if (session.isUpcoming && session.date != null)
          if (DateTime(
                session.date!.year,
                session.date!.month,
                session.date!.day,
              ) ==
              today)
            ScheduleItem(time: session.time, title: session.type, emoji: '🏋️'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DateTime now = nowKst();
    final String weekday = weekDayLabels(l)[now.weekday - 1];
    final String todayLabel = l.homeScheduleDate(weekday, now.month, now.day);
    // 트레이너 일정과 내가 만든 일정을 한 목록으로 보여 준다. 시간순으로 섞어야
    // '다음에 뭐가 있는지'를 한 번에 읽을 수 있다.
    final List<ScheduleItem> merged =
        <ScheduleItem>[
          ...items,
          ..._todaysSessions(
            ref.watch(coachSessionsProvider).valueOrNull ??
                const <CoachSession>[],
          ),
        ]..sort(
          (ScheduleItem first, ScheduleItem second) =>
              first.time.compareTo(second.time),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l.homeScheduleTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    todayLabel,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showScheduleCalendarSheet(context),
                child: Text(
                  l.homeViewAll,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (merged.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FigmaColors.softBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l.homeScheduleEmpty,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.foreground,
              ),
            ),
          )
        else
          for (int index = 0; index < merged.length; index++) ...<Widget>[
            _ScheduleItemCard(item: merged[index]),
            if (index != merged.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ScheduleItemCard extends StatelessWidget {
  const _ScheduleItemCard({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showScheduleCalendarSheet(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FigmaColors.softBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              Text(
                item.time,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 34,
                color: FigmaColors.primaryA(0.35),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: <Widget>[
                    if (item.emoji.isNotEmpty) ...<Widget>[
                      Text(item.emoji),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: FigmaColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.title});

  /// "주간 {지표} 추이" — 선택된 지표에 따라 바뀌는 그래프 왼쪽 상단 제목.
  final String title;

  @override
  Widget build(BuildContext context) {
    // 범례(이번 주/지난 주)와 목표 수치는 제거. 목표는 그래프 안의 목표선
    // 라벨이 말한다(#756).
    return Row(
      children: <Widget>[
        Expanded(
          // 그래프 제목은 그 그래프가 무슨 지표인지를 말한다 — 줄임표가 되면
          // (`Weekly Calories tre…`) 그 역할이 사라진다. 좁으면 줄인다. (#1004)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: FigmaColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
