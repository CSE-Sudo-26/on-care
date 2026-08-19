import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:oncare/core/utils/clock.dart';
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
        // 지표 버튼과 날짜 범위를 **한 줄에** 둔다. 범위만 따로 한 줄을 쓰면
        // 제목·범위·버튼 세 줄이 되어 정작 그래프가 아래로 밀린다.
        Row(
          children: <Widget>[
            for (final _Metric m in _Metric.values) ...<Widget>[
              _MetricPill(
                label: _label(l, m),
                // 버튼은 **무엇을 고르는가**만 말한다. 지표마다 색이 다르면
                // 고르기 전부터 셋이 서로 다른 뜻을 가진 것처럼 보인다.
                // 지표별 색은 아래 그래프가 계속 쓴다.
                color: FigmaColors.primary,
                active: _metric == m,
                onTap: () => setState(() => _metric = m),
              ),
              if (m != _Metric.values.last) const SizedBox(width: 8),
            ],
            const SizedBox(width: 8),
            // 좁은 화면에서 먼저 줄어드는 쪽은 범위다 — 버튼은 눌러야 하는
            // 것이라 잘리면 안 된다.
            Expanded(
              child: Text(
                l.dietPeriodRange(
                  fmt.format(widget.range.from),
                  fmt.format(widget.range.to),
                ),
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
                  // 세 지표가 같은 파랑을 쓴다. 지표마다 색이 다르면 같은
                  // 카드 안에서 버튼(파랑 통일)과 그래프가 서로 다른 말을
                  // 한다 — 목표를 넘긴 막대만 색으로 튄다(#694).
                  color: FigmaColors.primary,
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
                  // 칼로리 막대는 탄단지로 쌓아 그린다. 나트륨·당류는 쌓을
                  // 성분이 없으므로 지금처럼 한 색이다.
                  days: _metric == _Metric.calories ? period.days : null,
                  format: _number,
                  // 지표를 바꾸면 그래프가 처음부터 다시 그려진다.
                  replayKey: _metric,
                  metric: _metric,
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
    required this.metric,
    this.days,
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

  /// 칼로리 막대를 탄단지로 쌓기 위한 원본. 나트륨·당류를 볼 때는 null 이다.
  final List<DietPeriodDay>? days;

  /// 지금 고른 지표. 툴팁이 탄단지를 덧붙일지 판단한다.
  final _Metric metric;

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
              goalLabel:
                  '${AppLocalizations.of(context).homeGoal}\n${format(goal)}',
              formatTick: (double v) => format(v),
            )
          else
            _PeriodBars(
              values: values,
              dates: dates,
              goal: goal,
              color: color,
              replayKey: replayKey,
              // 막대 툴팁이 "무슨 값을 얼마나" 라고 말하려면 지표 이름·단위와
              // 숫자 서식이 카드 머리 숫자와 같아야 한다.
              metricLabel: metricLabel,
              unit: unit,
              format: format,
              days: days,
            ),
          // 쌓은 색이 무엇을 뜻하는지는 범례가 말한다 — 툴팁은 올려야 보인다.
          if (!weekly && days != null) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 6,
              children: <Widget>[
                _MacroLegend(
                  color: FigmaColors.macroCarbs,
                  label: l.homeMacroCarbs,
                ),
                _MacroLegend(
                  color: FigmaColors.macroProtein,
                  label: l.homeMacroProtein,
                ),
                _MacroLegend(
                  color: FigmaColors.macroFat,
                  label: l.homeMacroFat,
                ),
              ],
            ),
          ],
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
    required this.metricLabel,
    required this.unit,
    required this.format,
    this.days,
  });

  final List<double> values;
  final List<DateTime> dates;
  final double goal;
  final Color color;
  final Object replayKey;

  /// 칼로리를 볼 때의 원본. 탄단지가 있는 날은 막대를 셋으로 쌓는다.
  final List<DietPeriodDay>? days;

  /// 툴팁이 부를 지표 이름(칼로리·나트륨·당류)과 단위, 그리고 카드 머리 숫자와
  /// 같은 숫자 서식.
  final String metricLabel;
  final String unit;
  final String Function(num) format;

  /// [i] 번째 칸의 원본. 칼로리를 보고 있지 않으면 null 이다.
  DietPeriodDay? _dayAt(int i) {
    final List<DietPeriodDay>? source = days;
    if (source == null || i >= source.length) return null;
    return source[i];
  }

  /// 아직 오지 않은 날인가. (#950)
  ///
  /// 기록하지 않은 것이 아니라 **기록할 수 없는** 날이다. 둘을 같은 말로 그리면
  /// 한 달을 훑으며 "며칠을 빠뜨렸나" 를 셀 때 미래의 빈 칸까지 빠뜨린 날처럼
  /// 읽힌다 — 달 초에는 그 수가 스무 날이 넘는다.
  ///
  /// 운동 쪽은 트레이너 리포트의 `BarSeriesChart` 가 `pendingFromIndex` 로 이미
  /// 같은 구분을 한다(#754). 같은 규칙을 여기에도 둔다.
  bool _isPending(int i) =>
      DateUtils.dateOnly(dates[i]).isAfter(DateUtils.dateOnly(nowKst()));

  /// 한 막대의 툴팁 내용 — 운동 탭 `운동 현황` 툴팁과 같은 구조다.
  /// `[색 사각형] 지표  값 단위` 한 줄, 목표를 넘긴 날은 초과분을 한 줄 더.
  List<InlineSpan> _tipSpans(
    AppLocalizations l,
    DateFormat dayFormat,
    int i,
    bool hasGoal,
  ) {
    final double value = values[i];
    final bool over = hasGoal && value > goal;
    final List<InlineSpan> spans = <InlineSpan>[
      TextSpan(
        text: '${dayFormat.format(dates[i])}\n',
        style: const TextStyle(color: AppColors.mutedForeground),
      ),
    ];
    // 아직 오지 않은 날과 지나갔는데 비운 날은 다른 말이다(#950). 하루 평균이
    // 이미 **기록이 있는 날만으로** 나누므로, 계산은 둘을 구분하는데 화면만
    // 구분하지 않는 셈이었다.
    if (_isPending(i)) {
      spans.add(TextSpan(text: l.dietPeriodNotYet));
      return spans;
    }
    // 기록이 없는 날은 0 이 아니라 '기록 없음' 이다. 0 으로 적으면 굶은 날과
    // 적지 않은 날이 같은 말이 된다.
    if (value <= 0) {
      spans.add(TextSpan(text: l.dietPeriodNoRecord));
      return spans;
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: over ? FigmaColors.dangerRed : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
    spans.add(TextSpan(text: '$metricLabel   ${format(value)} $unit'));
    // 칼로리 뒤에는 그 칼로리가 어디서 왔는지를 적는다 — 숫자 하나만 보고는
    // 같은 2,000kcal 이 밥에서 왔는지 기름에서 왔는지 알 수 없다.
    final DietPeriodDay? day = _dayAt(i);
    if (day != null && day.hasMacros) {
      for (final ({Color color, String label, double grams}) m
          in <({Color color, String label, double grams})>[
            (
              color: FigmaColors.macroCarbs,
              label: l.homeMacroCarbs,
              grams: day.carbsG,
            ),
            (
              color: FigmaColors.macroProtein,
              label: l.homeMacroProtein,
              grams: day.proteinG,
            ),
            (
              color: FigmaColors.macroFat,
              label: l.homeMacroFat,
              grams: day.fatG,
            ),
          ]) {
        spans.add(const TextSpan(text: '\n'));
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: m.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
        spans.add(
          TextSpan(text: '${m.label}   ${format(m.grams)} ${l.dietUnitG}'),
        );
      }
    }
    // 막대가 왜 빨간지를 색이 아니라 글로도 말한다.
    if (over) {
      spans.add(
        TextSpan(
          text: '\n${l.dietPeriodOverGoal(format(value - goal), unit)}',
          style: const TextStyle(color: FigmaColors.dangerRed),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // `8월 12일 (화)` / `Tue, Aug 12` — 어느 막대가 며칠인지 x축 라벨만으로는
    // 짚을 수 없다(달은 6칸에 하나만 적는다).
    final DateFormat dayFormat = DateFormat.MMMEd(
      Localizations.localeOf(context).toString(),
    );
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
                          child: _Bar(
                            key: Key('diet-period-bar-$i'),
                            height:
                                chartHeight *
                                (values[i] / maxValue).clamp(0.0, 1.0) *
                                chartStagger(t, i, values.length),
                            pending: _isPending(i),
                            day: _dayAt(i),
                            // 목표를 넘긴 날은 한 색(경고)으로 칠한다. 쌓은
                            // 막대까지 빨갛게 물들이면 무엇이 얼마인지가
                            // 사라지므로, 탄단지가 있는 날은 쌓은 색을 지키고
                            // 초과는 목표선과 툴팁이 말한다.
                            over: hasGoal && values[i] > goal,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 막대 위에 겹치는 투명한 hover 영역. 운동 탭 `운동 현황` 이
              // 쓰는 것과 **같은 툴팁 규격**이라, 두 탭에서 같은 조작이 같은
              // 모양으로 답한다.
              Positioned.fill(
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < values.length; i++)
                      Expanded(
                        child: Tooltip(
                          key: Key('diet-period-bar-tip-$i'),
                          richMessage: TextSpan(
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: FigmaColors.ink,
                              height: 1.3,
                            ),
                            children: _tipSpans(l, dayFormat, i, hasGoal),
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

/// 한 칸의 막대. 탄단지가 있으면 아래에서부터 탄·단·지 순으로 쌓는다.
///
/// 쌓는 기준은 **칼로리**다(탄·단 4kcal/g, 지 9kcal/g). 그램으로 쌓으면 지방
/// 1g 이 탄수화물 1g 과 같은 높이를 차지해, 칼로리 막대인데 칼로리와 다른
/// 이야기를 하게 된다.
class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.height,
    required this.day,
    required this.over,
    required this.color,
    this.pending = false,
  });

  final double height;

  /// 아직 오지 않은 날인가. 지나간 빈 날의 그루터기보다 **더 옅게** 그린다 —
  /// 트레이너 리포트가 `pendingFromIndex` 에 쓰는 규칙과 같다(#754, #950).
  final bool pending;

  final DietPeriodDay? day;

  /// 목표를 넘긴 날인가. 쌓을 성분이 없을 때만 색으로 말한다.
  final bool over;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final DietPeriodDay? d = day;
    const BorderRadius radius = BorderRadius.vertical(top: Radius.circular(3));
    if (pending) {
      // 아직 오지 않은 날은 **빈 트랙**이다. 지나간 빈 날과 같은 그루터기를
      // 그리면 둘이 구분되지 않는다.
      return Container(
        height: 2,
        decoration: const BoxDecoration(
          color: FigmaColors.hairline,
          borderRadius: radius,
        ),
      );
    }
    if (d == null || !d.hasMacros) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: (over ? FigmaColors.dangerRed : color).withValues(alpha: 0.85),
          borderRadius: radius,
        ),
      );
    }
    final double total = d.carbsKcal + d.proteinKcal + d.fatKcal;
    if (total <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: radius,
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        // 위에서부터 지방·단백질·탄수화물 — 아래가 탄수화물이라 눈이 바닥부터
        // 읽는 순서가 라벨 순서(탄·단·지)와 같아진다.
        child: Column(
          // **stretch 여야 한다.** 기본값(center)이면 자식이 가로로 느슨하게
          // 제약되는데, 자식 없는 `ColoredBox` 의 고유 너비는 0 이라 세 구간이
          // 통째로 사라진다(#947). 한 색 막대가 멀쩡했던 이유는 그쪽이
          // `Container` 라서다 — 자식도 크기도 없는 Container 는 들어온 제약만큼
          // 커지려고 하므로 폭을 다 채운다.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: (d.fatKcal / total * 1000).round(),
              child: const ColoredBox(color: FigmaColors.macroFat),
            ),
            Expanded(
              flex: (d.proteinKcal / total * 1000).round(),
              child: const ColoredBox(color: FigmaColors.macroProtein),
            ),
            Expanded(
              flex: (d.carbsKcal / total * 1000).round(),
              child: const ColoredBox(color: FigmaColors.macroCarbs),
            ),
          ],
        ),
      ),
    );
  }
}

/// 탄단지 범례 한 칸.
class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedForeground,
        ),
      ),
    ],
  );
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
  final DateTime today = DateUtils.dateOnly(nowKst());
  for (int i = 0; i < dates.length; i++) {
    if (DateUtils.dateOnly(dates[i]) == today) return i;
  }
  return dates.length - 1;
}
