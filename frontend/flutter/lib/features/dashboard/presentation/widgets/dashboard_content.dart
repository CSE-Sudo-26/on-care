import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/ai_advice_text.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/presentation/widgets/trainer_chat_header_button.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/coaching_sheet.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// Home's own "/목표(단위)" suffix style. Same look as the shared
/// [kGoalSuffixStyle], one step larger so it scales with the rest of the Home
/// type; the other tabs keep the shared 9px size.
const TextStyle _kGoalSuffix = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w600,
  color: FigmaColors.textFaint,
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
            FigmaTabHeader(
              title: 'On - Care',
              leading: const HeartLogo(),
              trailingAction: const TrainerChatHeaderButton(),
              onBell: onNotificationTap,
              onCalendar: onCalendarTap,
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
                        onCoachingTap: () => showCoachingSheet(context),
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
              style: const TextStyle(color: FigmaColors.textMuted),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: _ScheduleCard(items: summary.todaySchedule),
        ),
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
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: FigmaColors.textBody,
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
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(child: _CardTitle(icon: icon, label: label)),
              const SizedBox(width: 6),
              // 필은 글자를 자르면 'AI ana…' 처럼 읽히지 않아 통째로 축소한다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AiPill(
                    l.homeAiAnalysisPill,
                    background: FigmaColors.primaryA(0.10),
                  ),
                ),
              ),
            ],
          ),
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
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: FigmaColors.iconTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: FigmaColors.primary),
        ),
        const SizedBox(width: 6),
        // 폭이 모자라면 제목부터 줄인다 — 아이콘·필·더보기는 남긴다(#440).
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────── diet + nutrition card ──
/// The merged 식단·영양 card: calorie ring + achievement, macro grams/goals,
/// and the weekly nutrition trend chart (legend + Y axis + point labels).
class _DietNutritionCard extends StatefulWidget {
  const _DietNutritionCard({
    required this.summary,
    required this.showCharts,
    required this.onOpen,
  });
  final DashboardSummary summary;
  final bool showCharts;
  final VoidCallback onOpen;

  @override
  State<_DietNutritionCard> createState() => _DietNutritionCardState();
}

class _DietNutritionCardState extends State<_DietNutritionCard> {
  /// 상단 지표 카드에서 고른 항목. 아래 그래프가 이 항목의 주간 추이를 그린다.
  _NutTabKind _tab = _NutTabKind.calories;

  @override
  Widget build(BuildContext context) {
    final DashboardSummary summary = widget.summary;
    final bool showCharts = widget.showCharts;
    final AppLocalizations l = AppLocalizations.of(context);
    final Map<_NutTabKind, _NutData> nutrition = _nutritionFor(summary);
    final _NutData cfg = nutrition[_tab]!;
    final List<String> days = _weekDayLabels(l);
    final int todayIdx = _todayIndex();
    final (double lo, double hi) = _trendScale(cfg, todayIdx);
    final NumberFormat nf = NumberFormat('#,###');

    return _HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardHeader(
            icon: Icons.restaurant_rounded,
            label: l.homeDietNutritionTitle,
            onOpen: widget.onOpen,
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
                    selected: _tab == kind,
                    onTap: () => setState(() => _tab = kind),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // 탄단지는 타일 없이 검은 텍스트로 가로 나열. 세 항목을 하나의
          // FittedBox 로 함께 축소해야 글자 크기가 서로 어긋나지 않는다
          // (항목별로 축소하면 가장 긴 '탄수화물'만 작아진다).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MacroText(
                  label: l.homeMacroCarbs,
                  grams: summary.macros.carbsG,
                  goalG: 275,
                ),
                const SizedBox(width: 14),
                _MacroText(
                  label: l.homeMacroProtein,
                  grams: summary.macros.proteinG,
                  goalG: 100,
                ),
                const SizedBox(width: 14),
                _MacroText(
                  label: l.homeMacroFat,
                  grams: summary.macros.fatG,
                  goalG: 55,
                ),
              ],
            ),
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
                      _ChartLegend(
                        title: l.homeWeeklyMetricTrend(_nutLabel(l, _tab)),
                        goalText:
                            '${l.homeGoal} ${nf.format(cfg.goal)}${cfg.unit}',
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // 가로축 눈금 라벨을 각 값의 실제 높이에 맞춰 배치.
                          SizedBox(
                            width: 34,
                            height: 60,
                            child: Stack(
                              children: <Widget>[
                                for (final double t in cfg.ticks)
                                  Positioned(
                                    right: 0,
                                    top: (60 - ((t - lo) / (hi - lo)) * 60 - 5)
                                        .clamp(0.0, 50.0),
                                    child: _AxisLabel(nf.format(t)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                SizedBox(
                                  height: 60,
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: _TrendChartPainter(
                                      cur: cfg.cur,
                                      goal: cfg.goal,
                                      ticks: cfg.ticks,
                                      lo: lo,
                                      hi: hi,
                                      todayIndex: todayIdx,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    for (int i = 0; i < days.length; i++)
                                      if (i == _todayIndex())
                                        // 오늘: #3EAFDF 원형 안에 흰색 요일 글씨.
                                        Container(
                                          width: 16,
                                          height: 16,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: FigmaColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            days[i],
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          days[i],
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: FigmaColors.textFaint,
                                          ),
                                        ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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
    final AppLocalizations l = AppLocalizations.of(context);
    final bool over =
        indicator.overBudget ||
        (indicator.max > 0 && indicator.current > indicator.max);
    final Color statusColor = over
        ? FigmaColors.dangerRed
        : FigmaColors.greenText;
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _metricNumber(indicator.current),
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
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
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  over ? l.homeMetricOver : l.homeMetricNormal,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
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

/// 탄단지 한 항목. 타일 없이 "탄수화물 120g /275g" 형태의 검은 텍스트로만
/// 표기하고, 세 항목을 가로로 나란히 놓는다.
class _MacroText extends StatelessWidget {
  const _MacroText({required this.label, required this.grams, this.goalG});

  final String label;
  final double grams;

  /// Optional daily target in grams, shown as a small "/275g" suffix.
  final int? goalG;

  @override
  Widget build(BuildContext context) {
    final value = grams == grams.roundToDouble()
        ? grams.toStringAsFixed(0)
        : grams.toStringAsFixed(1);
    // 축소는 세 항목을 감싼 바깥 FittedBox 가 한꺼번에 처리한다.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: FigmaColors.ink,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${value}g',
          maxLines: 1,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
        if (goalG != null)
          Text(
            ' /${goalG}g',
            maxLines: 1,
            // 목표치는 회색으로 낮춰 실제 섭취량(검정)과 구분.
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: FigmaColors.textMuted,
            ),
          ),
      ],
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l.homeDetails,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: FigmaColors.primary,
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: FigmaColors.primary),
        ],
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
class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.clip,
      softWrap: false,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: FigmaColors.textFaint,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── exercise card ──

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
    // AI 추천 운동까지 이미 더한 값이라, 아래 3지표와 주간 추이 차트가 같이 움직인다.
    // 로딩 전에는 summary 값으로 폴백.
    final ExerciseWeek? wk = ref.watch(exerciseWeekViewProvider).valueOrNull;
    final int minutes = wk?.totalMinutes ?? summary.exerciseMinutes;
    final int count = wk?.workoutCount ?? summary.exerciseCount;
    final double burned = (wk?.totalCalories ?? summary.exerciseCalories)
        .toDouble();
    // 오늘 요일(0=월 … 6=일). 오늘 이후(미래) 요일은 아직 운동 전이므로 0 으로
    // 두고, '오늘' 강조도 실제 오늘 요일에 붙인다.
    final int todayIdx = DateTime.now().weekday - 1;
    // 데모 상수는 주간 데이터가 아직 로드되지 않았을 때만 쓴다. 실제 데이터가
    // 있으면 그 일별 칼로리를 그대로 그린다(값이 없는 주는 빈 차트가 정답).
    final List<double> baseCal = (wk != null && wk.dailyCalories.isNotEmpty)
        ? wk.dailyCalories
        : _demoExerciseWeekCalories;
    final List<double> week = <double>[
      for (int i = 0; i < baseCal.length; i++)
        if (i > todayIdx) 0 else baseCal[i],
    ];
    final List<String> days = _weekDayLabels(l);
    final (double lo, double hi) = _barScale(week);
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
                      icon: Icons.timer_outlined,
                      label: l.homeExerciseActiveTime,
                      value: '$minutes',
                      goal: '150',
                      unit: l.unitMinutes,
                    ),
                    const SizedBox(height: 14),
                    _ExerciseStat(
                      icon: Icons.local_fire_department_rounded,
                      label: l.homeExerciseBurned,
                      value: nf.format(burned),
                      // 주간 소모 목표는 서버(exercise_burn_goal) 값을 쓴다.
                      // 운동 탭 '이번 주 운동 요약'도 같은 값을 읽어 두 화면이
                      // 항상 일치한다.
                      goal: nf.format(summary.exerciseBurnGoal),
                      unit: l.unitKcal,
                    ),
                    const SizedBox(height: 14),
                    _ExerciseStat(
                      icon: Icons.check_circle_outline_rounded,
                      label: l.homeExerciseDays,
                      // 값 = 주간 운동한 날짜 수(workoutCount), 목표 = 주 3일 이상.
                      value: '$count',
                      goal: '3',
                      unit: l.unitDays,
                    ),
                  ],
                ),
              ),
              if (showCharts) const SizedBox(width: 20),
              if (showCharts)
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${l.homeWeeklyExerciseTrend} (${l.unitKcal})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        key: const ValueKey<String>('dashboard-exercise-chart'),
                        height: 96,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _ExerciseBarPainter(
                            data: week,
                            lo: lo,
                            hi: hi,
                            todayIndex: todayIdx,
                            color: FigmaColors.primary,
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
                                child: i == todayIdx
                                    ? Container(
                                        width: 16,
                                        height: 16,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: FigmaColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          days[i],
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        days[i],
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: FigmaColors.textFaint,
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
        ],
      ),
    );
  }
}

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
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.textMuted,
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: FigmaColors.textMuted,
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
/// a nearly flat line.
(double, double) _trendScale(_NutData c, int todayIndex) {
  // 데이터와 눈금(ticks)을 모두 포함하도록 스케일을 잡아 눈금선이 항상 보이게 한다.
  final List<double> all = <double>[...c.cur, ...c.ticks, c.goal];
  double lo = all.reduce(math.min);
  double hi = all.reduce(math.max);
  final double range = (hi - lo) == 0 ? 1 : (hi - lo);
  hi += range * 0.10;
  lo -= range * 0.08;
  // 당류처럼 0이 최소 눈금인 지표는 바닥을 0에 고정.
  if (c.ticks.isNotEmpty && c.ticks.first <= 0 && lo < 0) lo = 0;
  return (lo, hi);
}

/// 목표 대비 상태색: 초과(빨강) / 그 외(초록).
///
/// 지표 카드의 초과·정상 뱃지와 같은 두 색(dangerRed/greenText)만 쓴다 —
/// 같은 카드 안에서 뱃지는 2단계인데 그래프만 근접(주황) 3단계라, 뱃지가
/// "정상"인 날의 점이 주황으로 찍혀 서로 다른 이야기를 했다. 이제 점은
/// 목표를 넘겼는지만 말한다.
Color _nutStatusColor(double v, double goal) =>
    v > goal ? FigmaColors.dangerRed : FigmaColors.greenText;

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

/// The API currently exposes today's totals, but not six days of history.
/// These historical points remain presentation-only demo data; [_nutritionFor]
/// replaces the final point with the live summary value.
const Map<_NutTabKind, _NutData>
_demoNutritionHistory = <_NutTabKind, _NutData>{
  _NutTabKind.calories: _NutData(
    // Monday through Saturday are demo history. Sunday is replaced at runtime.
    cur: <double>[1650, 2100, 1480, 1720, 1390, 1860, 967],
    unit: 'kcal',
    goal: 2000,
    ticks: <double>[1000, 1500, 2000, 2500],
    color: FigmaColors.primary,
    warn: false,
  ),
  _NutTabKind.sodium: _NutData(
    cur: <double>[1600, 1900, 2200, 1550, 1850, 2600, 3421],
    unit: 'mg',
    goal: 2000,
    ticks: <double>[1500, 2500, 3500],
    color: FigmaColors.orange,
    warn: true,
  ),
  _NutTabKind.sugar: _NutData(
    cur: <double>[30, 48, 22, 55, 18, 47, 14.8],
    unit: 'g',
    goal: 50,
    ticks: <double>[0, 25, 50],
    color: FigmaColors.sugarPurple,
    warn: false,
  ),
};

Map<_NutTabKind, _NutData> _nutritionFor(DashboardSummary summary) {
  final liveValues = <_NutTabKind, HealthIndicator>{
    _NutTabKind.calories: summary.calorieIndicator,
    _NutTabKind.sodium: summary.sodiumIndicator,
    _NutTabKind.sugar: summary.sugarIndicator,
  };
  // 오늘 라이브 값은 '마지막(일) 고정'이 아니라 실제 오늘 요일 자리에 넣는다.
  final int todayIdx = _todayIndex();
  return <_NutTabKind, _NutData>{
    for (final entry in _demoNutritionHistory.entries)
      entry.key: _NutData(
        cur: <double>[
          for (int i = 0; i < entry.value.cur.length; i++)
            i == todayIdx
                ? liveValues[entry.key]!.current.toDouble()
                : entry.value.cur[i],
        ],
        unit: entry.value.unit,
        goal: liveValues[entry.key]!.max.toDouble(),
        ticks: entry.value.ticks,
        color: entry.value.color,
        warn: liveValues[entry.key]!.overBudget,
      ),
  };
}

/// Presentation-only history until the dashboard API exposes daily exercise
/// series. Weekly live totals are shown separately in the metrics above.
// 운동 탭 '운동 현황(이번 주)' 일별 소모 칼로리와 일치시킨다(수 휴식, 일 활동).
// 월300·화420·목480·금400·토330·일520 = 운동 페이지 시드 하루 총합.
const List<double> _demoExerciseWeekCalories = <double>[
  300,
  420,
  0,
  480,
  400,
  330,
  520,
];

List<String> _weekDayLabels(AppLocalizations l) => <String>[
  l.dietWeekdayMon,
  l.dietWeekdayTue,
  l.dietWeekdayWed,
  l.dietWeekdayThu,
  l.dietWeekdayFri,
  l.dietWeekdaySat,
  l.dietWeekdaySun,
];

/// 오늘 요일 인덱스(0=월 … 6=일). 고정 라벨 배열 `_weekDayLabels` 와 함께 써서
/// 주간 차트의 '오늘' 배지·라이브 값을 실제 요일 칸에 배치하고, 오늘 이후(미래)
/// 요일의 0값이 급락처럼 보이지 않도록 렌더 범위를 오늘까지로 제한한다.
/// 홈 카드 전체가 이 하나만 쓴다(지표 카드·차트 기준이 어긋나지 않도록).
int _todayIndex() => DateTime.now().weekday - 1;

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
const Color _nutLineGray = Color(0xFFDDE2E8);

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.title, required this.goalText});

  /// "주간 {지표} 추이" — 선택된 지표에 따라 바뀌는 그래프 왼쪽 상단 제목.
  final String title;

  /// "목표 2,000kcal" 처럼 지표별 목표 수치. 그래프 오른쪽 상단에 표기.
  final String goalText;

  @override
  Widget build(BuildContext context) {
    // 범례(이번 주/지난 주)는 제거. 왼쪽에 그래프 제목, 오른쪽에 목표 수치를
    // 카드 우측 끝('자세히 >')과 같은 열로 맞춘다.
    //
    // 남는 가로 공간은 제목 쪽 Expanded 가 전부 흡수해야 목표 수치가 그래프
    // 오른쪽 끝에 붙는다. 목표 수치를 Expanded 로 두면 제목(Flexible)과 공간을
    // 반씩 나눠 가져 오른쪽 끝에서 한참 못 미친 자리에 멈춘다.
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          goalText,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: FigmaColors.primary,
          ),
        ),
      ],
    );
  }
}

/// The weekly nutrition trend line: a solid current-week line, solid
/// horizontal tick gridlines (uniform weight), and value labels on each
/// point. The goal is shown via the top label + point status colors, not a
/// separate line. The [lo]/[hi] scale is padded away from zero so the line
/// reads as a dynamic slope rather than a flat trace.
class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.cur,
    required this.goal,
    required this.ticks,
    required this.lo,
    required this.hi,
    required this.todayIndex,
  });

  final List<double> cur;
  final double goal;
  final List<double> ticks;
  final double lo;
  final double hi;

  /// 이번 주 꺾은선은 오늘까지만 그린다(미래 요일의 0값이 급락처럼 보이지 않도록).
  final int todayIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double span = (hi - lo) <= 0 ? 1 : (hi - lo);
    double dx(int i) => cur.length <= 1 ? w / 2 : (i / (cur.length - 1)) * w;
    double dy(double v) => h - ((v - lo) / span) * h;

    // 가로 눈금선: 지표별 눈금(ticks) 값마다 그린다.
    final Paint grid = Paint()
      ..color = const Color(0xFFEFF3F7)
      ..strokeWidth = 1;
    for (final double t in ticks) {
      if (t < lo || t > hi) continue;
      final double gy = dy(t);
      canvas.drawLine(Offset(0, gy), Offset(w, gy), grid);
    }
    // 목표선은 따로 그리지 않는다 — 목표값이 눈금과 겹치면 선이 두꺼워 보였다.
    // 목표는 상단 라벨(목표 N)과 데이터 포인트 상태색으로만 표현한다.

    // 이번 주 선/점은 오늘까지만 그린다 — 아직 오지 않은 요일(=0)을 실제 급락으로
    // 오해하지 않도록. x 좌표는 여전히 월~일 7칸 기준이라 지난 주 선과 정렬된다.
    final int lastIdx = todayIndex.clamp(0, cur.length - 1);
    final List<Offset> pts = <Offset>[
      for (int i = 0; i <= lastIdx; i++) Offset(dx(i), dy(cur[i])),
    ];

    // 이번 주 꺾은선은 회색(얇게), 데이터 포인트는 목표 대비 상태색으로 강조하고
    // 포인트마다 값을 같은 색으로 표기한다.
    final Path line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final Offset p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = _nutLineGray
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    for (int i = 0; i <= lastIdx; i++) {
      final Color sc = _nutStatusColor(cur[i], goal);
      _dot(canvas, pts[i], sc, r: i == cur.length - 1 ? 5.0 : 4.2);
      _text(canvas, _metricNumber(cur[i]), pts[i], w, sc);
    }
  }

  void _dot(Canvas c, Offset o, Color color, {double r = 3.0}) {
    c.drawCircle(o, r + 1.3, Paint()..color = Colors.white); // 흰 테두리(halo)
    c.drawCircle(o, r, Paint()..color = color); // 상태색으로 채운 데이터 포인트
  }

  void _text(Canvas c, String s, Offset at, double w, Color color) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    // 배경 상자 없이 값만 표기한다(포인트 위, 화면 밖으로 나가지 않게 clamp).
    final double bx = (at.dx - tp.width / 2).clamp(0.0, w - tp.width);
    double by = at.dy - tp.height - 7;
    if (by < 0) by = at.dy + 7;
    tp.paint(c, Offset(bx, by));
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) =>
      old.cur != cur ||
      old.goal != goal ||
      old.ticks != ticks ||
      old.lo != lo ||
      old.hi != hi ||
      old.todayIndex != todayIndex;
}

/// The weekly exercise bar chart. Bars sit on a [lo]/[hi] scale whose baseline
/// is pushed below the smallest value so day-to-day variation is pronounced;
/// each bar carries its kcal value label, and today's bar is highlighted.
class _ExerciseBarPainter extends CustomPainter {
  _ExerciseBarPainter({
    required this.data,
    required this.lo,
    required this.hi,
    required this.todayIndex,
    required this.color,
  });

  final List<double> data;
  final double lo;
  final double hi;

  /// 오늘 요일 인덱스(0=월 … 6=일). 마지막 막대 고정이 아니라 이 막대를 강조한다.
  final int todayIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double span = (hi - lo) <= 0 ? 1 : (hi - lo);
    final int n = data.length;
    final double slot = w / n;
    final double barW = math.min(slot * 0.5, 22);
    const double labelGap = 14;

    canvas.drawLine(
      Offset(0, h - 0.5),
      Offset(w, h - 0.5),
      Paint()
        ..color = const Color(0xFFEFF3F7)
        ..strokeWidth = 1,
    );

    for (int i = 0; i < n; i++) {
      final double v = data[i];
      final double bh = ((v - lo) / span) * (h - labelGap);
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
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: today ? color : const Color(0xFF9AA6B2),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final double lx = (cx - tp.width / 2).clamp(0.0, w - tp.width);
      tp.paint(canvas, Offset(lx, top - tp.height - 3));
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseBarPainter old) =>
      old.data != data ||
      old.lo != lo ||
      old.hi != hi ||
      old.todayIndex != todayIndex ||
      old.color != color;
}

// ───────────────────────────────────────────────────── recommended meals ──

class _RecMeal {
  const _RecMeal(
    this.photo,
    this.emoji,
    this.name,
    this.reason,
    this.bg,
    this.tag,
    this.tagColor,
  );

  /// Bundled dish photo shown on the card. [emoji] over [bg] is the fallback
  /// when the asset is missing, so the section still renders end-to-end.
  final String photo;
  final String emoji;
  final String name;
  final String reason;
  final Color bg;
  final String tag;
  final Color tagColor;

  /// 사진·태그·색은 그대로 두고 추천 이유 문구만 바꾼 사본.
  /// 서버가 개인화 문구를 보냈을 때 쓴다.
  _RecMeal withReason(String newReason) =>
      _RecMeal(photo, emoji, name, newReason, bg, tag, tagColor);
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
    FigmaColors.greenText,
  ),
  'brown_rice_box': _RecMeal(
    'assets/images/rec-brown-rice-box.jpg',
    '🍱',
    l.homeMealBrownRiceBox,
    l.homeMealReasonGlucose,
    const Color(0xFFFFF8E1),
    l.homeMealTagLowGi,
    FigmaColors.orangeText,
  ),
  'salmon': _RecMeal(
    'assets/images/rec-salmon-steak.jpg',
    '🐟',
    l.homeMealSalmon,
    l.homeMealReasonOmega,
    const Color(0xFFE3F2FD),
    l.homeMealTagHighProtein,
    FigmaColors.primary,
  ),
  'tofu': _RecMeal(
    'assets/images/rec-tofu-broccoli.png',
    '🥦',
    l.homeMealTofu,
    l.homeMealReasonLowCal,
    const Color(0xFFF3E5F5),
    l.homeMealTagLowCal,
    FigmaColors.sugarPurple,
  ),
  'namul_bibimbap': _RecMeal(
    'assets/images/rec-namul-bibimbap.png',
    '🥬',
    l.homeMealNamulBibimbap,
    l.homeMealReasonFiber,
    const Color(0xFFEFF7ED),
    l.homeMealTagHighFiber,
    FigmaColors.greenText,
  ),
};

/// 이유 코드 → 기본 문구. 서버가 개인화 문구(`reasonText`)를 주지 않았을 때 쓴다.
/// 요리별 기본 이유는 카탈로그에 고정돼 있어, 이 경로면 화면이 서버 연동 이전과
/// 완전히 같아진다.
String? _reasonTextFor(AppLocalizations l, String reasonKey) => switch (reasonKey) {
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
    final List<_RecMeal> meals = _cardsFor(l, recs);
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
                    AiPill(
                      l.homeAiAnalysisPill,
                      background: FigmaColors.primaryA(0.10),
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
        SizedBox(
          // 세로 여백은 카드 그림자가 리스트 뷰포트에 잘리지 않게 하는 용도
          // (카드 자체 높이는 158 그대로).
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            itemCount: meals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, int i) => _RecMealCard(meal: meals[i]),
          ),
        ),
      ],
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
          Image.asset(
            meal.photo,
            height: 72,
            width: double.infinity,
            fit: BoxFit.cover,
            // Fall back to the emoji tile if the bundled photo is missing.
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                _emojiHeader(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: Text(
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
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: meal.tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      meal.tag,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: meal.tagColor,
                      ),
                    ),
                  ),
                ],
              ),
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.items});

  final List<ScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DateTime now = DateTime.now();
    final String weekday = _weekDayLabels(l)[now.weekday - 1];
    final String todayLabel = l.homeScheduleDate(weekday, now.month, now.day);
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
                      fontSize: 13.5,
                      color: FigmaColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showScheduleCalendarSheet(context),
              child: Text(
                l.homeViewAll,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
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
                fontSize: 13.5,
                color: FigmaColors.textSub,
              ),
            ),
          )
        else
          for (int index = 0; index < items.length; index++) ...<Widget>[
            _ScheduleItemCard(item: items[index]),
            if (index != items.length - 1) const SizedBox(height: 8),
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
    return GestureDetector(
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
            Container(width: 1, height: 34, color: FigmaColors.primaryA(0.35)),
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
    );
  }
}
