import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/diet/domain/entities/diet_period.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/metric_trend_chart.dart';

/// 식단 탭의 기간 뷰(이번 주 / 이번 달).
///
/// 홈은 식단을 주간으로도 보여주는데 식단 탭에는 하루치밖에 없었다(#670). 운동
/// 탭의 `운동 현황` 과 같은 기간 토글 아래에서, 고른 지표(칼로리·나트륨·당류)의
/// 일별 막대와 **하루 평균**을 보여준다. 합계가 아니라 평균을 머리 숫자로 두는
/// 이유는 주(7일)와 달(30일)의 길이가 달라 합계끼리는 견줄 수 없기 때문이다.
class DietPeriodView extends ConsumerStatefulWidget {
  const DietPeriodView({
    required this.range,
    required this.weekly,
    this.profile,
    super.key,
  });

  final DietDateRange range;

  /// 이번 주인가. 주간은 홈 탭과 **같은 꺾은선**으로, 이번 달은 일별 막대로
  /// 그린다 — 30칸을 꺾은선으로 그리면 점과 값 라벨이 서로 겹친다.
  final bool weekly;

  final UserProfile? profile;

  @override
  ConsumerState<DietPeriodView> createState() => _DietPeriodViewState();
}

enum _Metric { calories, sodium, sugar }

class _DietPeriodViewState extends ConsumerState<DietPeriodView> {
  _Metric _metric = _Metric.calories;

  String _label(AppLocalizations l, _Metric m) => switch (m) {
    _Metric.calories => l.dietCalories,
    _Metric.sodium => l.dietSodium,
    _Metric.sugar => l.dietSugar,
  };

  String _unit(AppLocalizations l, _Metric m) => switch (m) {
    _Metric.calories => l.unitKcal,
    _Metric.sodium => l.dietUnitMg,
    _Metric.sugar => l.dietUnitG,
  };

  Color _color(_Metric m) => switch (m) {
    _Metric.calories => FigmaColors.primary,
    _Metric.sodium => FigmaColors.orange,
    _Metric.sugar => FigmaColors.sugarPurple,
  };

  double _valueOf(DietPeriodDay d, _Metric m) => switch (m) {
    _Metric.calories => d.calories.toDouble(),
    _Metric.sodium => d.sodiumMg.toDouble(),
    _Metric.sugar => d.sugarG,
  };

  double _averageOf(DietPeriod p, _Metric m) => switch (m) {
    _Metric.calories => p.avgCalories,
    _Metric.sodium => p.avgSodiumMg,
    _Metric.sugar => p.avgSugarG,
  };

  int _goalOf(_Metric m) {
    final UserProfile? p = widget.profile;
    return switch (m) {
      _Metric.calories =>
        p?.effectiveDailyCalories ?? UserProfile.defaultDailyCalories,
      _Metric.sodium =>
        p?.effectiveDailySodiumMg ?? UserProfile.defaultDailySodiumMg,
      _Metric.sugar =>
        p?.effectiveDailySugarG ?? UserProfile.defaultDailySugarG,
    };
  }

  /// 꺾은선의 가로 눈금. **홈 탭과 같은 값**이라 두 화면의 눈금이 어긋나지
  /// 않는다(`dashboard_content.dart` 의 지표 설정과 짝).
  List<double> _ticks(_Metric m) => switch (m) {
    _Metric.calories => const <double>[0, 1500, 2500],
    _Metric.sodium => const <double>[0, 1750, 3500],
    _Metric.sugar => const <double>[0, 25, 50],
  };

  /// 소수 첫째 자리까지만 남기고 정수는 콤마만 붙인다(당류 17.8 이 18 로
  /// 반올림돼 하루 뷰와 어긋나지 않도록).
  String _number(num v) => v == v.roundToDouble()
      ? NumberFormat('#,###').format(v)
      : NumberFormat('#,##0.#').format(v);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<DietPeriod> async = ref.watch(
      dietPeriodProvider(widget.range),
    );
    final DateFormat fmt = DateFormat.MMMd(
      Localizations.localeOf(context).toString(),
    );

    // 바깥 섹션(영양 요약)이 이미 제목과 좌우 여백을 갖는다 — 여기서 또 두면
    // 제목이 두 줄로 겹치고 여백이 이중으로 들어간다(#681).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            l.dietPeriodRange(
              fmt.format(widget.range.from),
              fmt.format(widget.range.to),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (final _Metric m in _Metric.values) ...<Widget>[
              _MetricPill(
                label: _label(l, m),
                color: _color(m),
                active: _metric == m,
                onTap: () => setState(() => _metric = m),
              ),
              if (m != _Metric.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
          error: (Object e, StackTrace _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: <Widget>[
                Text(
                  l.dietLoadError,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  // 실패는 날짜별 provider 에 남아 있다. 집계만 무효화하면
                  // 같은 에러를 다시 읽어 와 아무 일도 일어나지 않는다.
                  onPressed: () {
                    for (final DateTime d in dietRangeDates(widget.range)) {
                      ref.invalidate(dietByDateProvider(d));
                    }
                    ref.invalidate(dietPeriodProvider(widget.range));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FigmaColors.primary,
                    side: BorderSide(color: FigmaColors.primaryA(0.4)),
                  ),
                  child: Text(l.actionRetry),
                ),
              ],
            ),
          ),
          data: (DietPeriod period) => period.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      l.dietPeriodEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                )
              : _PeriodBody(
                  period: period,
                  metricLabel: _label(l, _metric),
                  unit: _unit(l, _metric),
                  color: _color(_metric),
                  average: _averageOf(period, _metric),
                  goal: _goalOf(_metric).toDouble(),
                  total: period.days.fold<double>(
                    0,
                    (double a, DietPeriodDay d) => a + _valueOf(d, _metric),
                  ),
                  values: <double>[
                    for (final DietPeriodDay d in period.days)
                      _valueOf(d, _metric),
                  ],
                  dates: <DateTime>[
                    for (final DietPeriodDay d in period.days) d.date,
                  ],
                  format: _number,
                  // 지표를 바꾸면 그래프가 처음부터 다시 그려진다.
                  replayKey: _metric,
                  weekly: widget.weekly,
                  ticks: _ticks(_metric),
                ),
        ),
      ],
    );
  }
}

class _PeriodBody extends StatelessWidget {
  const _PeriodBody({
    required this.period,
    required this.metricLabel,
    required this.unit,
    required this.color,
    required this.average,
    required this.goal,
    required this.total,
    required this.values,
    required this.dates,
    required this.format,
    required this.replayKey,
    required this.weekly,
    required this.ticks,
  });

  final DietPeriod period;
  final String metricLabel;
  final String unit;
  final Color color;
  final double average;
  final double goal;
  final double total;
  final List<double> values;
  final List<DateTime> dates;
  final String Function(num) format;
  final Object replayKey;

  /// 이번 주면 꺾은선, 이번 달이면 막대.
  final bool weekly;

  /// 꺾은선의 가로 눈금. 홈 탭과 같은 값을 쓴다.
  final List<double> ticks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<String> labels = weekDayLabels(l);
    final bool over = goal > 0 && average > goal;
    final Color statusColor = over
        ? FigmaColors.dangerRed
        : FigmaColors.greenText;
    return Container(
      key: const Key('diet-period-card'),
      width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${l.dietPeriodAverage} · $metricLabel',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: format(average),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: over
                                    ? FigmaColors.dangerRed
                                    : FigmaColors.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${format(goal)} $unit',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  over
                      ? '${l.homeGoal} ${l.homeMetricOver}'
                      : l.homeMetricNormal,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                l.dietPeriodLoggedDays(period.loggedDays),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${l.dietPeriodTotal} ${format(total)} $unit',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: FigmaColors.hairline),
          const SizedBox(height: 14),
          if (weekly)
            MetricTrendChart(
              values: values,
              dayLabels: <String>[
                for (final DateTime d in dates) labels[d.weekday - 1],
              ],
              goal: goal,
              ticks: ticks,
              // 이번 주는 오늘까지만 잇는다. 오늘이 이 범위 밖이면(지난 주를
              // 보고 있으면) 마지막 칸까지 전부 그린다.
              todayIndex: _todayIndexIn(dates),
              replayKey: replayKey,
              formatTick: (double v) => format(v),
            )
          else
            _PeriodBars(
              values: values,
              dates: dates,
              goal: goal,
              color: color,
              replayKey: replayKey,
            ),
        ],
      ),
    );
  }
}

/// 일별 막대. 목표선을 얇은 점선처럼 얹어 그날이 목표를 넘었는지 한눈에 보이게
/// 하고, 목표를 넘은 날만 경고색으로 칠한다.
class _PeriodBars extends StatelessWidget {
  const _PeriodBars({
    required this.values,
    required this.dates,
    required this.goal,
    required this.color,
    required this.replayKey,
  });

  final List<double> values;
  final List<DateTime> dates;
  final double goal;
  final Color color;
  final Object replayKey;

  @override
  Widget build(BuildContext context) {
    const double chartHeight = 120;
    // 축 위쪽에 여유를 둔다. 목표를 넘은 날이 없으면 목표가 곧 최댓값이 되어
    // 목표선이 차트 맨 위(=바깥)에 놓여 잘려 보이지 않았다.
    final double peak = <double>[
      goal,
      ...values,
    ].fold<double>(1, (double a, double b) => b > a ? b : a);
    final double maxValue = peak * 1.15;
    // 목표가 0이면(프로필에 목표를 0으로 넣은 경우) 초과 판정을 하지 않는다 —
    // 카드 위쪽 배지도 같은 규칙이라, 배지는 '정상'인데 막대만 빨간 일이 없다.
    final bool hasGoal = goal > 0;
    // 달(30칸)에서도 라벨이 겹치지 않도록 몇 칸에 하나만 적는다.
    final int labelStep = values.length > 10 ? (values.length / 6).ceil() : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: <Widget>[
              if (hasGoal)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: chartHeight * (goal / maxValue).clamp(0.0, 1.0),
                  child: const Divider(
                    height: 1,
                    thickness: 1,
                    color: FigmaColors.hairline,
                  ),
                ),
              // 막대 전체를 하나의 ChartReveal 로 감싸고 순서만 어긋내
              // (chartStagger) 준다. 막대마다 애니메이션을 두면 한 달치에
              // 티커가 31개 생긴다.
              ChartReveal(
                curve: Curves.linear,
                replayKey: replayKey,
                builder: (BuildContext context, double t) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (int i = 0; i < values.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Container(
                            key: Key('diet-period-bar-$i'),
                            height:
                                chartHeight *
                                (values[i] / maxValue).clamp(0.0, 1.0) *
                                chartStagger(t, i, values.length),
                            decoration: BoxDecoration(
                              color: hasGoal && values[i] > goal
                                  ? FigmaColors.dangerRed.withValues(
                                      alpha: 0.85,
                                    )
                                  : color.withValues(alpha: 0.85),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (int i = 0; i < dates.length; i++)
              Expanded(
                child: Text(
                  i % labelStep == 0 ? '${dates[i].day}' : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : FigmaColors.statBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? color : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// 오늘이 이 범위의 몇 번째 칸인가. 범위 밖이면 마지막 칸 — 지난 주를 보고
/// 있을 때 선이 중간에서 끊기지 않게 한다.
int _todayIndexIn(List<DateTime> dates) {
  final DateTime today = DateUtils.dateOnly(DateTime.now());
  for (int i = 0; i < dates.length; i++) {
    if (DateUtils.dateOnly(dates[i]) == today) return i;
  }
  return dates.length - 1;
}
