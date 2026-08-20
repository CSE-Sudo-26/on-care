import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/activity_charts.dart';
import 'package:oncare_trainer/shared/widgets/chart_semantics.dart';
import 'package:oncare_trainer/shared/widgets/metric_trend_chart.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 고객의 기간 영양 추이 — 회원 앱 식단 탭 기간 뷰와 **같은 것**을 트레이너에게.
/// (#914)
///
/// 머리 숫자를 합계가 아니라 **하루 평균**으로 두는 이유는 주(7일)와 달(30일)의
/// 길이가 달라 합계끼리는 견줄 수 없기 때문이다. 평균은 기록이 있는 날만으로
/// 나눈다 — 아직 오지 않은 날까지 나누면 달 초에는 늘 낮게 나온다.
class ClientDietPeriodCard extends ConsumerStatefulWidget {
  /// Creates the period chart for [clientId] over [period].
  const ClientDietPeriodCard({
    super.key,
    required this.clientId,
    required this.period,
  });

  final String clientId;

  /// `오늘` 은 이 카드가 아니라 영양 요약 카드가 맡는다.
  final ClientPeriod period;

  @override
  ConsumerState<ClientDietPeriodCard> createState() =>
      _ClientDietPeriodCardState();
}

/// 기간 그래프가 그리는 지표.
enum _Metric { calories, sodium, sugar }

class _ClientDietPeriodCardState extends ConsumerState<ClientDietPeriodCard> {
  _Metric _metric = _Metric.calories;

  String _label(AppLocalizations l, _Metric m) => switch (m) {
    _Metric.calories => l.metricCalories,
    _Metric.sodium => l.metricSodium,
    _Metric.sugar => l.metricSugar,
  };

  String _unit(_Metric m) => switch (m) {
    _Metric.calories => 'kcal',
    _Metric.sodium => 'mg',
    _Metric.sugar => 'g',
  };

  double _valueOf(ClientDietDay d, _Metric m) => switch (m) {
    _Metric.calories => d.calories.toDouble(),
    _Metric.sodium => d.sodiumMg.toDouble(),
    _Metric.sugar => d.sugarG,
  };

  double _averageOf(ClientDietPeriod p, _Metric m) => switch (m) {
    _Metric.calories => p.avgCalories,
    _Metric.sodium => p.avgSodiumMg,
    _Metric.sugar => p.avgSugarG,
  };

  /// 하루 목표. 회원 앱 기본값과 같은 값을 쓴다 — 회원이 자기 폰에서 초과라고
  /// 본 날이 트레이너 화면에서도 초과여야 한다.
  double _goalOf(_Metric m) => switch (m) {
    _Metric.calories => calorieTargetKcal.toDouble(),
    _Metric.sodium => sodiumTargetMg.toDouble(),
    _Metric.sugar => sugarTargetG.toDouble(),
  };

  /// 꺾은선의 세로 눈금. **회원 앱과 같은 값**이라 회원이 보는 그래프와
  /// 트레이너가 보는 그래프의 눈금이 어긋나지 않는다.
  List<double> _ticks(_Metric m) => switch (m) {
    _Metric.calories => const <double>[0, 1500, 2500],
    _Metric.sodium => const <double>[0, 1750, 3500],
    _Metric.sugar => const <double>[0, 25, 50],
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 키에 오늘 날짜가 들어간다 — 자정을 넘기면 다음 rebuild 가 새 범위를 묻는다.
    final ClientPeriodKey key = clientPeriodKeyNow(
      widget.clientId,
      widget.period,
    );
    final AsyncValue<ClientDietPeriod> async = ref.watch(
      clientDietPeriodProvider(key),
    );
    // 제목·아이콘은 바깥 `ClientPeriodSection` 이 든다(#944). 카드가 자기
    // 제목을 들고 있으면 기간을 바꿀 때마다 제목이 나타났다 사라진다.
    return _Card(
      child: async.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (Object e, StackTrace _) => EmptyHint(
          message: l.dietLoadFailed,
          icon: Icons.error_outline,
          action: ActionButton(
            key: const ValueKey<String>('client-diet-period-retry'),
            label: l.actionRetry,
            onPressed: () => ref.invalidate(clientDietPeriodProvider(key)),
          ),
        ),
        data: (ClientDietPeriod period) => period.isEmpty
            ? EmptyHint(
                message: l.clientPeriodEmpty,
                icon: Icons.restaurant_outlined,
              )
            : _Body(
                period: period,
                metric: _metric,
                onMetric: (_Metric m) => setState(() => _metric = m),
                label: _label(l, _metric),
                unit: _unit(_metric),
                average: _averageOf(period, _metric),
                goal: _goalOf(_metric),
                values: <double>[
                  for (final ClientDietDay d in period.days)
                    _valueOf(d, _metric),
                ],
                logged: <bool>[
                  for (final ClientDietDay d in period.days) d.logged,
                ],
                dates: <DateTime>[
                  for (final ClientDietDay d in period.days) d.date,
                ],
                // 칼로리 막대만 탄단지로 쌓는다. 나트륨·당류에는 쌓을 성분이
                // 없다.
                days: _metric == _Metric.calories ? period.days : null,
                weekly: widget.period == ClientPeriod.week,
                ticks: _ticks(_metric),
                // 영양 요약 카드와 **같은 서식**을 쓴다. 두 카드가 같은
                // 화면에 나란히 놓이므로 표기가 갈리면 바로 드러난다.
                format: formatNumber,
                metricLabel: _label,
              ),
      ),
    );
  }
}

/// 제목 없는 흰 판 — 영양 요약 카드·운동 카드와 같은 모양이다.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('client-diet-period-card'),
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.card),
      boxShadow: kCardShadow,
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.period,
    required this.metric,
    required this.onMetric,
    required this.label,
    required this.unit,
    required this.average,
    required this.goal,
    required this.values,
    required this.logged,
    required this.dates,
    required this.format,
    required this.metricLabel,
    required this.weekly,
    required this.ticks,
    this.days,
  });

  final ClientDietPeriod period;
  final _Metric metric;
  final ValueChanged<_Metric> onMetric;
  final String label;
  final String unit;
  final double average;
  final double goal;
  final List<double> values;
  final List<bool> logged;
  final List<DateTime> dates;
  final String Function(num) format;
  final String Function(AppLocalizations, _Metric) metricLabel;

  /// 칼로리를 볼 때의 원본. 탄단지가 있는 날은 막대를 셋으로 쌓는다.
  final List<ClientDietDay>? days;

  /// 이번 주인가. 회원 앱과 같이 **주는 꺾은선, 달은 막대**다 — 30칸을
  /// 꺾은선으로 그리면 점과 값이 서로 겹친다.
  final bool weekly;

  /// 꺾은선의 세로 눈금. 회원 앱 홈·식단 탭과 같은 값이라 두 화면의 눈금이
  /// 어긋나지 않는다.
  final List<double> ticks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool over = goal > 0 && average > goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 지표 버튼은 **무엇을 고르는가**만 말한다. 지표마다 색이 다르면 고르기
        // 전부터 셋이 서로 다른 뜻을 가진 것처럼 보인다.
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final _Metric m in _Metric.values)
              _MetricPill(
                label: metricLabel(l, m),
                active: metric == m,
                onTap: () => onMetric(m),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${l.clientPeriodAverage} · $label',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subtleForeground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: format(average),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: over
                              ? AppColors.overTarget
                              : AppColors.foreground,
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: ' / ${format(goal)} $unit',
                            style: const TextStyle(
                              fontSize: 11,
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
            const SizedBox(width: AppSpacing.sm),
            Text(
              l.clientPeriodLoggedDays(period.loggedDays),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (weekly)
          Builder(
            builder: (BuildContext context) {
              final days = <String>[
                for (final DateTime d in dates) _weekdayLabel(l, d),
              ];
              final today = _todayIndexIn(dates);
              return MetricTrendChart(
                values: values,
                dayLabels: days,
                goal: goal,
                ticks: ticks,
                // 선은 오늘까지만 잇는다. 아직 오지 않은 요일의 0 이 급락처럼
                // 보이면 안 된다.
                todayIndex: today,
                replayKey: label,
                // 카드 머리의 지표 이름으로 시작한다 — 음성 안내에서도 이
                // 그래프가 무엇의 것인지가 먼저 들린다(#972).
                semanticsLabel: chartSemanticsLabel(
                  l,
                  title: label,
                  points: chartSeriesPoints(
                    l,
                    values: values,
                    dayLabels: days,
                    format: (double v) => '${format(v)} $unit',
                    upTo: today,
                  ),
                ),
                goalLabel: '${l.clientPeriodGoal}\n${format(goal)}',
                formatTick: (double v) => format(v),
              );
            },
          )
        else ...<Widget>[
          _PeriodBars(
            values: values,
            logged: logged,
            dates: dates,
            goal: goal,
            unit: unit,
            label: label,
            format: format,
            days: days,
          ),
          // 쌓은 색이 무엇을 뜻하는지는 범례가 말한다 — 툴팁은 올려야 보인다.
          if (days != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                ActivityLegend(
                  color: AppColors.macroCarbs,
                  label: l.metricCarbs,
                ),
                ActivityLegend(
                  color: AppColors.macroProtein,
                  label: l.metricProtein,
                ),
                ActivityLegend(color: AppColors.macroFat, label: l.metricFat),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// 요일 라벨(월…일).
String _weekdayLabel(AppLocalizations l, DateTime d) => <String>[
  l.weekdayMon,
  l.weekdayTue,
  l.weekdayWed,
  l.weekdayThu,
  l.weekdayFri,
  l.weekdaySat,
  l.weekdaySun,
][d.weekday - 1];

/// 오늘이 이 범위의 몇 번째 칸인가. 범위 밖이면 마지막 칸 — 지난 주를 보고
/// 있을 때 선이 중간에서 끊기지 않게 한다.
int _todayIndexIn(List<DateTime> dates) {
  final DateTime today = todayKst();
  for (int i = 0; i < dates.length; i++) {
    final DateTime d = dates[i];
    if (DateTime(d.year, d.month, d.day) == today) return i;
  }
  return dates.length - 1;
}

/// 일별 막대. 목표선을 얇게 얹고, 목표를 넘긴 날만 경고색으로 칠한다 —
/// 회원 앱 식단 탭의 같은 그래프와 규칙이 같다.
class _PeriodBars extends StatelessWidget {
  const _PeriodBars({
    required this.values,
    required this.logged,
    required this.dates,
    required this.goal,
    required this.unit,
    required this.label,
    required this.format,
    this.days,
  });

  final List<double> values;
  final List<bool> logged;
  final List<DateTime> dates;
  final double goal;
  final String unit;
  final String label;
  final String Function(num) format;

  /// 칼로리를 볼 때의 원본. 탄단지가 있는 날은 막대를 셋으로 쌓는다.
  final List<ClientDietDay>? days;

  /// [i] 번째 칸의 원본. 칼로리를 보고 있지 않으면 null 이다.
  ClientDietDay? _dayAt(int i) {
    final List<ClientDietDay>? source = days;
    if (source == null || i >= source.length) return null;
    return source[i];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const double chartHeight = 108;
    // 축 위에 여유를 둔다. 목표를 넘은 날이 없으면 목표가 곧 최댓값이 되어
    // 목표선이 차트 맨 위(=바깥)에 놓여 잘려 보인다.
    final double peak = <double>[
      goal,
      ...values,
    ].fold<double>(1, (double a, double b) => math.max(a, b));
    final double maxValue = peak * 1.15;
    final bool hasGoal = goal > 0;
    // 달(30칸)에서도 라벨이 겹치지 않도록 몇 칸에 하나만 적는다.
    final int labelStep = values.length > 10 ? (values.length / 6).ceil() : 1;
    // 기록이 하나도 없는 달은 막대마다 `기록 없음` 을 서른 번 읽히는 대신 비어
    // 있다고 한 번만 말한다(#972).
    final bool empty = logged.every((bool it) => !it);

    return Semantics(
      container: true,
      label: empty
          ? chartSemanticsLabel(l, title: label, points: const <String>[])
          : null,
      child: ExcludeSemantics(
        excluding: empty,
        child: Column(
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
                        color: AppColors.borderStrong,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (int i = 0; i < values.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1.5,
                            ),
                            // 툴팁은 올려야 보인다. 같은 내용을 시맨틱 라벨로도
                            // 준다 — 막대 하나가 며칠 얼마인지는 이 노드 말고는
                            // 음성 안내에 나올 데가 없다(#972).
                            child: Semantics(
                              label: _tip(l, i)
                                  .split('\n')
                                  .map((String s) => s.trim())
                                  .join(', '),
                              child: Tooltip(
                                key: Key('client-diet-bar-$i'),
                                message: _tip(l, i),
                                child: _MacroBar(
                                  height:
                                      chartHeight *
                                      (values[i] / maxValue).clamp(0.0, 1.0),
                                  day: _dayAt(i),
                                  logged: logged[i],
                                  // 목표를 넘긴 날은 한 색(경고)으로 칠한다. 쌓은
                                  // 막대까지 빨갛게 물들이면 무엇이 얼마인지가
                                  // 사라지므로, 탄단지가 있는 날은 쌓은 색을 지키고
                                  // 초과는 목표선과 툴팁이 말한다.
                                  over: hasGoal && values[i] > goal,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: <Widget>[
                for (int i = 0; i < dates.length; i++)
                  Expanded(
                    child: Text(
                      i % labelStep == 0 ? '${dates[i].day}' : '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 막대 하나의 툴팁 — 어느 막대가 며칠인지는 x축 라벨만으로 짚을 수 없다.
  String _tip(AppLocalizations l, int i) {
    final DateTime at = dates[i];
    final String date = '${at.month}/${at.day}';
    if (!logged[i]) return '$date · ${l.chartNoRecord}';
    final String head = '$date · $label ${format(values[i])} $unit';
    // 칼로리 뒤에는 그 칼로리가 어디서 왔는지를 적는다 — 숫자 하나만 보고는
    // 같은 2,000kcal 이 밥에서 왔는지 기름에서 왔는지 알 수 없다.
    final ClientDietDay? d = _dayAt(i);
    if (d == null || !d.hasMacros) return head;
    return '$head'
        '\n${l.metricCarbs} ${format(d.carbsG)}g'
        '  ${l.metricProtein} ${format(d.proteinG)}g'
        '  ${l.metricFat} ${format(d.fatG)}g';
  }
}

/// 한 칸의 막대. 탄단지가 있으면 아래에서부터 탄·단·지 순으로 쌓는다.
///
/// 쌓는 기준은 **칼로리**다(탄·단 4kcal/g, 지 9kcal/g). 그램으로 쌓으면 지방
/// 1g 이 탄수화물 1g 과 같은 높이를 차지해, 칼로리 막대인데 칼로리와 다른
/// 이야기를 하게 된다.
class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.height,
    required this.day,
    required this.logged,
    required this.over,
  });

  final double height;
  final ClientDietDay? day;

  /// 그날 기록이 있었는가. 없으면 색 없는 그루터기다.
  final bool logged;

  /// 목표를 넘긴 날인가. 쌓을 성분이 없을 때만 색으로 말한다.
  final bool over;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.vertical(top: AppRadius.xs);
    final ClientDietDay? d = day;
    final double total = d == null
        ? 0
        : d.carbsKcal + d.proteinKcal + d.fatKcal;
    if (d == null || !d.hasMacros || total <= 0) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        decoration: BoxDecoration(
          color: !logged
              // 기록이 없는 날은 색이 없다 — 0 으로 칠하면 '적지 않은 날' 이
              // '0kcal 먹은 날' 이 된다.
              ? AppColors.border
              : over
              ? AppColors.overTarget.withValues(alpha: 0.85)
              : AppColors.primary.withValues(alpha: 0.85),
          borderRadius: radius,
        ),
      );
    }
    // 막대 **높이**는 칼로리를 따른다(목표선과 견주려면 그래야 한다). 그런데
    // 구간 비율만 탄단지 합계로 잡으면, 둘이 어긋나는 날에 구간이 실제 기여분
    // 보다 크게 그려진다 — 1,800kcal 인 날의 탄단지가 1,200kcal 어치뿐이어도
    // 세 색이 막대를 꽉 채워, 없는 기여분을 지어내는 셈이다.
    //
    // 그래서 분모를 **둘 중 큰 값**으로 둔다. 탄단지가 칼로리에 못 미치면 남는
    // 만큼이 `나머지` 로 위에 남고, 넘치면 탄단지 합계에 맞춰 꽉 찬다.
    final double basis = math.max(d.calories.toDouble(), total);
    final double rest = basis - total;
    // 값이 있는 구간만 만든다. `flex: 0` 이 터지지는 않지만(확인함), 셋이 모두
    // 0 으로 반올림되면 높이만 있고 아무것도 그려지지 않은 막대가 남는다 —
    // #947 과 같은 종류의 사라짐이다. 그래서 남는 구간에는 **최소 1** 을 준다:
    // 아주 적게 먹은 영양소는 실오라기로라도 보이는 편이 없는 것보다 낫다.
    //
    // 위에서부터 나머지·지방·단백질·탄수화물 — 아래가 탄수화물이라 눈이 바닥부터
    // 읽는 순서가 범례 순서(탄·단·지)와 같아진다.
    final List<({Color color, double kcal})> parts =
        <({Color color, double kcal})>[
          // 어느 영양소로도 설명되지 않는 칼로리. 반올림 때문에 생기는
          // 실오라기는 그리지 않는다 — 1% 를 넘을 때만 자리를 준다.
          if (rest / basis > 0.01)
            (color: AppColors.borderStrong, kcal: rest),
          if (d.fatKcal > 0) (color: AppColors.macroFat, kcal: d.fatKcal),
          if (d.proteinKcal > 0)
            (color: AppColors.macroProtein, kcal: d.proteinKcal),
          if (d.carbsKcal > 0) (color: AppColors.macroCarbs, kcal: d.carbsKcal),
        ];
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: Column(
          // **stretch 여야 한다.** 기본값(center)이면 자식이 가로로 느슨하게
          // 제약되는데, 자식 없는 `ColoredBox` 의 고유 너비는 0 이라 구간이
          // 통째로 사라진다(회원 앱 #947 에서 밟은 함정).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final ({Color color, double kcal}) part in parts)
              Expanded(
                flex: math.max(1, (part.kcal / basis * 1000).round()),
                child: ColoredBox(color: part.color),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `GestureDetector` 가 아니라 `InkWell` 이다. 트레이너 앱은 웹·데스크톱에서도
    // 쓰이는데, 탭만 받는 위젯은 Tab 포커스와 Enter 를 받지 못해 마우스 없이는
    // 지표를 바꿀 수 없었다. 같은 화면의 `_ClientDataTab` 이 이미 쓰는 방식이다.
    return Semantics(
      button: true,
      selected: active,
      child: Container(
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.inputBackground,
          borderRadius: const BorderRadius.all(AppRadius.pill),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.35)
                : const Color(0x00000000),
          ),
          boxShadow: active ? kCardShadow : null,
        ),
        child: Material(
          color: const Color(0x00000000),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
