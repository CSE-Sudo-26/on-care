import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/coaching_sheet.dart';

/// The Home tab, rebuilt to match the On-Care Figma redesign.
///
/// Sections (top → bottom): header, greeting, AI coaching banner, a merged
/// 식단·영양 card (calorie ring + weekly nutrition trend) and a full-width
/// 운동 card (activity metrics + burn goal + weekly trend),
/// 이번 주 AI 추천 식단 carousel, 오늘의 일정. Per the product decision the
/// 건강 지표 (심박수·수면) cards and the sleep AI-coaching banner are omitted.
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
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 108),
          children: <Widget>[
            _HomeHeader(
              onNotificationTap: onNotificationTap,
              onCalendarTap: onCalendarTap,
              onProfileTap: () => context.go(AppRoutes.myHealth),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  // Greet by the signed-in user's name; fall back to a
                  // name-less greeting while the profile loads or is empty.
                  final String name =
                      ref.watch(profileProvider).valueOrNull?.name.trim() ?? '';
                  return Text(
                    name.isEmpty ? l.homeGreetingGeneric : l.homeGreeting(name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.textMuted,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: _CoachingBanner(onTap: () => showCoachingSheet(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _DietNutritionCard(
                onOpen: () => context.go(AppRoutes.diet),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: _ExerciseCard(
                onOpen: () => context.go(AppRoutes.exercise),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: _RecommendedMeals(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: _ScheduleCard(),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── header ──

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    this.onNotificationTap,
    this.onCalendarTap,
    this.onProfileTap,
  });

  final VoidCallback? onNotificationTap;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: <Widget>[
          const HeartLogo(),
          const SizedBox(width: 8),
          // 헤더 브랜드명은 "On - Care" (탭 제목 appTitle="On-Care"와 별개).
          const Text(
            'On - Care',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _RoundIconButton(
            onTap: onNotificationTap,
            showDot: true,
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 18,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          _RoundIconButton(
            onTap: onCalendarTap,
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          _ProfileAvatar(onTap: onProfileTap),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.child,
    this.onTap,
    this.showDot = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Material(
            color: FigmaColors.softBlue,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(child: child),
            ),
          ),
          if (showDot)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: FigmaColors.redDot,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFE8F6FC), Color(0xFFB8E4F5)],
                ),
                border: Border.all(color: FigmaColors.primary, width: 2.2),
              ),
              child: const Icon(
                Icons.person,
                size: 22,
                color: FigmaColors.primary,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: FigmaColors.onlineGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────── coaching banner ──

class _CoachingBanner extends StatelessWidget {
  const _CoachingBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[FigmaColors.bannerStart, FigmaColors.bannerEnd],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FigmaColors.primaryA(0.18)),
            boxShadow: kCardShadow,
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '오늘의 AI 통합 조언',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '아침 식단과 저녁 PT 수업은 완벽했습니다! 다만 점심 짬뽕으로 '
                            '높아진 나트륨과 혈당을 낮추기 위해, 물을 충분히 마시고 '
                            '코치님이 강조하신 어깨 스트레칭으로 오늘 하루를 건강하게 '
                            '마무리해 보세요.',
                            style: TextStyle(
                              fontSize: 12,
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

/// Shared white card chrome for the two Home summary cards, including the
/// gradient top stripe.
class _StripeCard extends StatelessWidget {
  const _StripeCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FigmaColors.primaryA(0.08)),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[FigmaColors.primary, FigmaColors.primaryStripe],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
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
  const _DietNutritionCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  State<_DietNutritionCard> createState() => _DietNutritionCardState();
}

class _DietNutritionCardState extends State<_DietNutritionCard> {
  _NutTabKind _tab = _NutTabKind.calories;

  static const double _calCur = 967; // 식단 탭 오늘 합계와 일치
  static const double _calGoal = 2000; // MY 건강목표 칼로리

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final double calPct = (_calCur / _calGoal).clamp(0.0, 1.0);
    final _NutData cfg = _nutrition[_tab]!;
    final List<String> days = _weekDayLabels(l);
    final (double lo, double hi) = _trendScale(cfg);
    final NumberFormat nf = NumberFormat('#,###');
    // 오늘 값의 목표 대비 상태색(안전 초록 / 근접 주황 / 초과 빨강).
    final Color todayColor = _nutStatusColor(cfg.cur.last, cfg.goal);

    return _StripeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _CardTitle(
                icon: Icons.restaurant_rounded,
                label: l.homeDietNutritionTitle,
              ),
              const SizedBox(width: 6),
              AiPill(
                l.homeAiAnalysisPill,
                background: FigmaColors.primaryA(0.10),
              ),
              const Spacer(),
              _DetailLink(onTap: widget.onOpen),
            ],
          ),
          const SizedBox(height: 14),
          // Calorie hero: ring + concrete kcal + achievement chip.
          Row(
            children: <Widget>[
              _CalorieRing(pct: calPct),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            l.homeCalorieIntake,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FigmaColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 오늘 나트륨 과다(짬뽕) 경고 뱃지.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF04438).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '나트륨 초과',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF04438),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          nf.format(_calCur),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.ink,
                            letterSpacing: -0.5,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ ${nf.format(_calGoal)} ${l.unitKcal}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: FigmaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SoftDivider(),
          const SizedBox(height: 10),
          // 지표 버튼(칼로리/나트륨/당류)을 그래프 왼쪽에 세로로 배치해 카드 높이를 줄인다.
          Row(
            children: <Widget>[
              // 동일 크기 버튼(가장 넓은 라벨 기준 + stretch). 나트륨 주의 표시 없음.
              IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final _NutTabKind t in _nutrition.keys) ...<Widget>[
                      _NutTab(
                        label: _nutLabel(l, t),
                        active: _tab == t,
                        warn: false,
                        // 세 버튼 모두 선택 시 브랜드 블루(#3EAFDF)로 통일.
                        activeColor: FigmaColors.primary,
                        onTap: () => setState(() => _tab = t),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ChartLegend(
                      goalText: '${l.homeGoal} ${nf.format(cfg.goal)}${cfg.unit}',
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
                                  top:
                                      (60 -
                                              ((t - lo) / (hi - lo)) * 60 -
                                              5)
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
                                    prev: cfg.prev,
                                    goal: cfg.goal,
                                    ticks: cfg.ticks,
                                    lo: lo,
                                    hi: hi,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  for (int i = 0; i < days.length; i++)
                                    Text(
                                      days[i],
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: i == 6
                                            ? todayColor
                                            : FigmaColors.textFaint,
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

/// The calorie achievement ring (reuses [_RingPainter]) with a centred %.
class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    const double size = 54;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(size, size),
            painter: _RingPainter(
              pct: pct,
              track: const Color(0xFFE8F5FB),
              arc: FigmaColors.primary,
              stroke: 5,
            ),
          ),
          Text(
            '${(pct * 100).round()}%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
        ],
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l.homeDetails,
            style: const TextStyle(
              fontSize: 12,
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

/// A small sub-section heading ("주간 추이") with a leading tinted icon.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: FigmaColors.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
        ),
      ],
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
        fontSize: 7.5,
        fontWeight: FontWeight.w600,
        color: FigmaColors.textFaint,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── exercise card ──

/// The full-width 운동 card: activity metrics (time / kcal / count), the burn
/// goal progress, and a weekly burned-calories trend chart with value labels.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.onOpen});
  final VoidCallback onOpen;

  static const double _burned = 520; // 오늘 PT 소모 칼로리 (운동 탭과 일치)
  static const double _burnGoal = 500;
  // 운동 탭 '운동 현황(이번 주)'의 요일 패턴과 일치(수=휴식, 일=오늘 PT).
  static const List<double> _week = <double>[300, 430, 0, 470, 400, 320, 520];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final double pct = (_burned / _burnGoal).clamp(0.0, 1.0);
    // 진행바는 100%로 채우되, 라벨의 달성률은 실제 비율(목표 초과 시 100% 초과)을 보여준다.
    const double rawPct = _burned / _burnGoal;
    final List<String> days = _weekDayLabels(l);
    final (double lo, double hi) = _barScale(_week);
    final NumberFormat nf = NumberFormat('#,###');

    return _StripeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _CardTitle(
                icon: Icons.fitness_center_rounded,
                label: l.dashboardMetricExercise,
              ),
              const SizedBox(width: 6),
              AiPill(
                l.homeAiAnalysisPill,
                background: FigmaColors.primaryA(0.10),
              ),
              const Spacer(),
              _DetailLink(onTap: onOpen),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricTile(
                  icon: Icons.timer_outlined,
                  // 운동 탭 오늘 도넛 기본값(유산소15+근력40+스트레칭10=65)과 일치.
                  value: '65',
                  unit: l.unitMinutes,
                  label: l.homeExerciseActiveTime,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.local_fire_department_rounded,
                  value: nf.format(_burned),
                  unit: l.unitKcal,
                  label: l.homeExerciseBurned,
                  color: FigmaColors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.check_circle_outline_rounded,
                  value: '4',
                  unit: l.unitTimes,
                  label: l.homeExerciseCount,
                  color: FigmaColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                l.homeExerciseBurnProgress,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.textSub,
                ),
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: nf.format(_burned),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: FigmaColors.primary,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' / ${nf.format(_burnGoal)} ${l.unitKcal}'
                          '  ·  ${(rawPct * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Fill(
            pct: pct,
            height: 8,
            gradient: const LinearGradient(
              colors: <Color>[FigmaColors.primary, FigmaColors.primaryStripe],
            ),
          ),
          const SizedBox(height: 6),
          const _SoftDivider(),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _SectionLabel(
                icon: Icons.bar_chart_rounded,
                text: l.homeWeeklyTrend,
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: FigmaColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${l.homeLegendToday} · ${l.unitKcal}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ExerciseBarPainter(
                data: _week,
                lo: lo,
                hi: hi,
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
                    child: Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: i == 6
                            ? FigmaColors.primary
                            : FigmaColors.textFaint,
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

/// A single activity metric tile (icon chip + big value + unit + label).
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.ink,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Padded min/max scale for the nutrition line chart. Deliberately excludes a
/// zero baseline so day-to-day variation reads as a dynamic slope rather than
/// a nearly flat line.
(double, double) _trendScale(_NutData c) {
  // 데이터와 눈금(ticks)을 모두 포함하도록 스케일을 잡아 눈금선이 항상 보이게 한다.
  final List<double> all = <double>[...c.cur, ...c.prev, ...c.ticks, c.goal];
  double lo = all.reduce(math.min);
  double hi = all.reduce(math.max);
  final double range = (hi - lo) == 0 ? 1 : (hi - lo);
  hi += range * 0.10;
  lo -= range * 0.08;
  // 당류처럼 0이 최소 눈금인 지표는 바닥을 0에 고정.
  if (c.ticks.isNotEmpty && c.ticks.first <= 0 && lo < 0) lo = 0;
  return (lo, hi);
}

/// 목표 대비 상태색: 초과(빨강) / 근접 90%↑(주황) / 안전(초록).
Color _nutStatusColor(double v, double goal) {
  if (v > goal) return const Color(0xFFF04438);
  if (v >= goal * 0.9) return FigmaColors.orange;
  return const Color(0xFF34C759);
}

/// Padded scale for the exercise bar chart. The baseline sits well below the
/// smallest bar so the difference between days is visually pronounced.
(double, double) _barScale(List<double> d) {
  final double hi = d.reduce(math.max);
  // 0을 기준선으로 삼아 값이 0인 날은 막대가 0에 가깝게, 위쪽에 여유를 둬
  // 막대가 카드 높이를 꽉 채우지 않도록 한다.
  return (0, hi <= 0 ? 1 : hi * 1.3);
}

/// An intrinsic-safe horizontal progress fill. Uses a flex split rather than
/// [FractionallySizedBox] so it survives [IntrinsicHeight]'s intrinsic-sizing
/// pass (FractionallySizedBox throws during that pass).
class _Fill extends StatelessWidget {
  const _Fill({required this.pct, this.gradient, this.height = 4});

  final double pct;
  final Gradient? gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final int filled = (pct.clamp(0.0, 1.0) * 1000).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: filled,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
            Expanded(
              flex: 1000 - filled,
              child: const ColoredBox(color: FigmaColors.track),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.pct,
    required this.track,
    required this.arc,
    required this.stroke,
  });
  final double pct;
  final Color track;
  final Color arc;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (math.min(size.width, size.height) - stroke) / 2;
    final Paint trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);
    final Paint arcPaint = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * pct.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.pct != pct || old.arc != arc || old.track != track;
}

// ───────────────────────────────────────────────────── nutrition data ──

class _NutData {
  const _NutData({
    required this.cur,
    required this.prev,
    required this.unit,
    required this.goal,
    required this.ticks,
    required this.color,
    required this.warn,
  });
  final List<double> cur;
  final List<double> prev;
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

const Map<_NutTabKind, _NutData> _nutrition = <_NutTabKind, _NutData>{
  _NutTabKind.calories: _NutData(
    // 오늘(일) = 식단 탭 합계 967 kcal 로 일치. 목표 2,000 기준으로 안전(초록)·
    // 근접(주황 1,860)·초과(빨강 2,100)가 모두 나타나도록 구성.
    cur: <double>[1650, 2100, 1480, 1720, 1390, 1860, 967],
    prev: <double>[1820, 1950, 1700, 1800, 1650, 2050, 1610],
    unit: 'kcal',
    goal: 2000,
    ticks: <double>[1000, 1500, 2000, 2500],
    color: FigmaColors.primary,
    warn: false,
  ),
  _NutTabKind.sodium: _NutData(
    // 오늘(일) = 식단 탭 합계 3,421 mg (짬뽕 나트륨 스파이크) 로 일치. 목표 2,000
    // 기준 안전(초록 1,600/1,550)·근접(주황 1,900/1,850)·초과(빨강 2,200+)가 공존.
    cur: <double>[1600, 1900, 2200, 1550, 1850, 2600, 3421],
    prev: <double>[1900, 2000, 1950, 2100, 2050, 2200, 2180],
    unit: 'mg',
    goal: 2000,
    ticks: <double>[1500, 2500, 3500],
    color: FigmaColors.orange,
    warn: true,
  ),
  _NutTabKind.sugar: _NutData(
    // 오늘(일) = 식단 탭 합계 14.8 g 로 일치. 목표 50 기준 안전(초록)·근접(주황
    // 48/47)·초과(빨강 55)가 모두 나타나도록 구성.
    cur: <double>[30, 48, 22, 55, 18, 47, 14.8],
    prev: <double>[35, 38, 30, 40, 28, 44, 32],
    unit: 'g',
    goal: 50,
    ticks: <double>[0, 25, 50],
    color: FigmaColors.sugarPurple,
    warn: false,
  ),
};

List<String> _weekDayLabels(AppLocalizations l) => <String>[
  l.dietWeekdayMon,
  l.dietWeekdayTue,
  l.dietWeekdayWed,
  l.dietWeekdayThu,
  l.dietWeekdayFri,
  l.dietWeekdaySat,
  l.dietWeekdaySun,
];

/// Maps an internal nutrition key (used for tab identity) to its localized
/// display label.
String _nutLabel(AppLocalizations l, _NutTabKind key) => switch (key) {
  _NutTabKind.calories => l.dashboardMetricCalories,
  _NutTabKind.sodium => l.dietSodium,
  _NutTabKind.sugar => l.dietSugar,
};

class _NutTab extends StatelessWidget {
  const _NutTab({
    required this.label,
    required this.active,
    required this.warn,
    required this.activeColor,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool warn;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : FigmaColors.track,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : FigmaColors.textMuted,
              ),
            ),
            if (warn && !active) ...<Widget>[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: FigmaColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            if (warn && active) ...<Widget>[
              const SizedBox(width: 4),
              const Text('⚠️', style: TextStyle(fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }
}

const Color _nutLineGray = Color(0xFF98A2B3); // 이번 주 꺾은선(회색)
const Color _nutGoalGray = Color(0xFFCBD2DA); // 목표 점선(옅은 회색)
const Color _nutLastWeek =
    Color(0xFFAC93F2); // 지난 주 꺾은선(sugarPurple 기반, 살짝 쨍·살짝 연하게)
const Color _nutLabelBg = Color(0xFFEFF1F4); // 데이터 값 라벨 배경(연한 회색)
const TextStyle _legendStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w600,
  color: FigmaColors.textMuted,
);

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.goalText});

  /// "목표 2,000kcal" 처럼 지표별 목표 수치. 그래프 오른쪽 상단에 표기.
  final String goalText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _item(
          const SizedBox(
            width: 16,
            child: Divider(color: _nutLineGray, thickness: 2, height: 2),
          ),
          AppLocalizations.of(context).homeLegendThisWeek,
        ),
        const SizedBox(width: 10),
        _item(
          const SizedBox(
            width: 16,
            child: Divider(color: _nutLastWeek, thickness: 1.6, height: 2),
          ),
          AppLocalizations.of(context).homeLegendLastWeek,
        ),
        const Spacer(),
        // 목표 수치는 그래프 오른쪽 상단에 브랜드 블루로 크게 배치.
        // 좁은 화면·영어 로케일에서 범례가 넘치지 않도록 Flexible+말줄임.
        Flexible(
          child: Text(
            goalText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: FigmaColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(Widget swatch, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      swatch,
      const SizedBox(width: 4),
      Text(text, style: _legendStyle),
    ],
  );
}

/// The weekly nutrition trend line: a dashed previous week, a filled current
/// week with gradient area, a dashed goal line, and value labels on the peak
/// and today's point. The [lo]/[hi] scale is padded away from zero so the
/// line reads as a dynamic slope rather than a flat trace.
class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.cur,
    required this.prev,
    required this.goal,
    required this.ticks,
    required this.lo,
    required this.hi,
  });

  final List<double> cur;
  final List<double> prev;
  final double goal;
  final List<double> ticks;
  final double lo;
  final double hi;

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

    // 목표선(옅은 회색 점선).
    if (goal >= lo && goal <= hi) {
      _dash(canvas, Offset(0, dy(goal)), Offset(w, dy(goal)), _nutGoalGray, 1.2);
    }

    // 지난 주(연한 보라 점선).
    for (int i = 0; i < prev.length - 1; i++) {
      _dash(
        canvas,
        Offset(dx(i), dy(prev[i])),
        Offset(dx(i + 1), dy(prev[i + 1])),
        _nutLastWeek,
        1.4,
      );
    }

    final List<Offset> pts = <Offset>[
      for (int i = 0; i < cur.length; i++) Offset(dx(i), dy(cur[i])),
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

    for (int i = 0; i < cur.length; i++) {
      final Color sc = _nutStatusColor(cur[i], goal);
      _dot(canvas, pts[i], sc, r: i == cur.length - 1 ? 4.2 : 3.4);
      _text(canvas, _fmt(cur[i]), pts[i], w, sc);
    }
  }

  // Keep one decimal for fractional values (당류 14.8g stays 14.8, not 15) so
  // the home bubble matches the 식단 탭 요약 수치.
  String _fmt(double v) => v == v.roundToDouble()
      ? NumberFormat('#,###').format(v)
      : NumberFormat('#,##0.#').format(v);

  void _dot(Canvas c, Offset o, Color color, {double r = 3.0}) {
    c.drawCircle(o, r + 1.3, Paint()..color = Colors.white); // 흰 테두리(halo)
    c.drawCircle(o, r, Paint()..color = color); // 상태색으로 채운 데이터 포인트
  }

  void _text(Canvas c, String s, Offset at, double w, Color color) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    // 값마다 연한 회색 둥근 네모 배경.
    const double padX = 3.5, padY = 1.5;
    final double bw = tp.width + padX * 2;
    final double bh = tp.height + padY * 2;
    final double bx = (at.dx - bw / 2).clamp(0.0, w - bw);
    double by = at.dy - bh - 6;
    if (by < 0) by = at.dy + 6;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(4),
      ),
      Paint()..color = _nutLabelBg,
    );
    tp.paint(c, Offset(bx + padX, by + padY));
  }

  void _dash(Canvas c, Offset a, Offset b, Color color, double width) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = width;
    const double dash = 3, gap = 3;
    final double total = (b - a).distance;
    if (total == 0) return;
    final Offset dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) =>
      old.cur != cur ||
      old.prev != prev ||
      old.goal != goal ||
      old.ticks != ticks ||
      old.lo != lo ||
      old.hi != hi;
}

/// The weekly exercise bar chart. Bars sit on a [lo]/[hi] scale whose baseline
/// is pushed below the smallest value so day-to-day variation is pronounced;
/// each bar carries its kcal value label, and today's bar is highlighted.
class _ExerciseBarPainter extends CustomPainter {
  _ExerciseBarPainter({
    required this.data,
    required this.lo,
    required this.hi,
    required this.color,
  });

  final List<double> data;
  final double lo;
  final double hi;
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
      final bool today = i == n - 1;
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
            fontSize: 8.5,
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
      old.data != data || old.lo != lo || old.hi != hi || old.color != color;
}

// ───────────────────────────────────────────────────── recommended meals ──

class _RecMeal {
  const _RecMeal(
    this.emoji,
    this.name,
    this.reason,
    this.bg,
    this.tag,
    this.tagColor,
  );
  final String emoji;
  final String name;
  final String reason;
  final Color bg;
  final String tag;
  final Color tagColor;
}

List<_RecMeal> _recMeals(AppLocalizations l) => <_RecMeal>[
  _RecMeal(
    '🥗',
    l.homeMealChickenSalad,
    l.homeMealReasonSodium,
    const Color(0xFFE8F5E9),
    l.homeMealTagLowSodium,
    FigmaColors.greenText,
  ),
  _RecMeal(
    '🍱',
    l.homeMealBrownRiceBox,
    l.homeMealReasonGlucose,
    const Color(0xFFFFF8E1),
    l.homeMealTagLowGi,
    FigmaColors.orangeText,
  ),
  _RecMeal(
    '🐟',
    l.homeMealSalmon,
    l.homeMealReasonOmega,
    const Color(0xFFE3F2FD),
    l.homeMealTagHighProtein,
    FigmaColors.primary,
  ),
  _RecMeal(
    '🥦',
    l.homeMealTofu,
    l.homeMealReasonLowCal,
    const Color(0xFFF3E5F5),
    l.homeMealTagLowCal,
    FigmaColors.sugarPurple,
  ),
  _RecMeal(
    '🥬',
    l.homeMealNamulBibimbap,
    l.homeMealReasonFiber,
    const Color(0xFFEFF7ED),
    l.homeMealTagHighFiber,
    FigmaColors.greenText,
  ),
];

class _RecommendedMeals extends StatelessWidget {
  const _RecommendedMeals();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<_RecMeal> meals = _recMeals(l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: <Widget>[
              Text(
                l.homeRecMealsTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              AiPill(
                l.homeAiAnalysisPill,
                background: FigmaColors.primaryA(0.10),
              ),
              const Spacer(),
              Text(
                l.homeViewAll,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.primary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0D000000)),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 72,
            width: double.infinity,
            color: meal.bg,
            alignment: Alignment.center,
            child: Text(meal.emoji, style: const TextStyle(fontSize: 32)),
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
                    fontSize: 11,
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
                      fontSize: 9.5,
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
                      fontSize: 9,
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
}

// ───────────────────────────────────────────────────────── schedule ──

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();

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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    todayLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: FigmaColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              l.homeViewAll,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FigmaColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FigmaColors.softBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FigmaColors.primaryA(0.12)),
          ),
          child: Row(
            children: <Widget>[
              const Text(
                '19:30',
                style: TextStyle(
                  fontSize: 15,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.homeScheduleEveningWalk,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.homeScheduleWalkDetail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FigmaColors.textSub,
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
      ],
    );
  }
}
