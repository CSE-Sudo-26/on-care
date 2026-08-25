import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/nutrition_summary_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/chart_semantics.dart';
import 'package:oncare_trainer/shared/widgets/metric_trend_chart.dart';
import 'package:oncare_trainer/shared/widgets/period_scroll_chart.dart';
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

  /// `전체` 그래프의 스크롤 위치와 고른 날. (#1018)
  final PeriodChartSelection _selection = PeriodChartSelection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

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
    final ClientDateRange range = clientRangeFor(widget.period, key.day);
    // 제목·아이콘은 바깥 `ClientPeriodSection` 이 든다(#944). 카드가 자기
    // 제목을 들고 있으면 기간을 바꿀 때마다 제목이 나타났다 사라진다.
    //
    // 지표 버튼과 기간 범위는 **카드 밖**이다 — 회원 앱과 같은 자리다. 카드
    // 안에 두면 읽는 중에 그래프가 아래로 밀리고, 무엇보다 기록이 없는 기간
    // (`clientPeriodEmpty`)에서 버튼까지 함께 사라져 지표를 되돌릴 방법이
    // 없어진다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MetricRow(
          metric: _metric,
          onMetric: (_Metric m) {
            // 지표를 바꾸면 고른 날의 숫자는 뜻을 잃는다 — 같이 푼다.
            _selection.reset();
            setState(() => _metric = m);
          },
          metricLabel: _label,
          range: range,
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
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
                    selection: _selection,
                    period: period,
                    metric: _metric,
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
                  ),
          ),
        ),
      ],
    );
  }
}

/// 카드 **위**의 지표 버튼 줄 — `칼로리 · 나트륨 · 당류` 와 기간 범위.
///
/// 회원 앱 `DietPeriodView` 와 같이 한 줄에 둔다. 범위를 따로 한 줄에 두면
/// 제목·범위·버튼 세 줄이 되어 정작 그래프가 아래로 밀린다.
///
/// 버튼은 **무엇을 고르는가**만 말한다. 지표마다 색이 다르면 고르기 전부터
/// 셋이 서로 다른 뜻을 가진 것처럼 보인다 — 지표별 색은 아래 그래프가 쓴다.
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.onMetric,
    required this.metricLabel,
    required this.range,
  });

  final _Metric metric;
  final ValueChanged<_Metric> onMetric;
  final String Function(AppLocalizations, _Metric) metricLabel;
  final ClientDateRange range;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DateFormat fmt = DateFormat.MMMd(
      Localizations.localeOf(context).toString(),
    );
    return Row(
      children: <Widget>[
        for (final _Metric m in _Metric.values) ...<Widget>[
          _MetricPill(
            label: metricLabel(l, m),
            active: metric == m,
            onTap: () => onMetric(m),
          ),
          if (m != _Metric.values.last) const SizedBox(width: AppSpacing.sm),
        ],
        const SizedBox(width: AppSpacing.sm),
        // 좁은 화면에서 먼저 줄어드는 쪽은 범위다 — 버튼은 눌러야 하는 것이라
        // 잘리면 안 된다.
        Expanded(
          child: Text(
            '${fmt.format(range.from)} ~ ${fmt.format(range.to)}',
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
    );
  }
}

/// 제목 없는 흰 판 — 영양 요약 카드·운동 카드와 같은 모양이다.
///
/// 높이는 `오늘` 카드와 같은 [kClientNutritionCardHeight] 를 바닥으로 둔다
/// (#1167) — 기간 토글을 눌렀을 때 카드가 커졌다 작아지면 그 아래 날짜별 기록이
/// 그때마다 뛴다. 최소 높이라 글자 배율이 커지면 함께 커진다.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('client-diet-period-card'),
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: kClientNutritionCardHeight),
    padding: const EdgeInsets.all(AppSpacing.lg),
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
    required this.label,
    required this.unit,
    required this.average,
    required this.goal,
    required this.values,
    required this.logged,
    required this.dates,
    required this.format,
    required this.weekly,
    required this.ticks,
    required this.selection,
    this.days,
  });

  final ClientDietPeriod period;
  final _Metric metric;
  final String label;
  final String unit;
  final double average;
  final double goal;
  final List<double> values;
  final List<bool> logged;
  final List<DateTime> dates;
  final String Function(num) format;

  /// 칼로리를 볼 때의 원본. 탄단지가 있는 날은 막대를 셋으로 쌓는다.
  final List<ClientDietDay>? days;

  /// 이번 주인가. 회원 앱과 같이 **주는 꺾은선, 달은 막대**다 — 30칸을
  /// 꺾은선으로 그리면 점과 값이 서로 겹친다.
  final bool weekly;

  /// 꺾은선의 세로 눈금. 회원 앱 홈·식단 탭과 같은 값이라 두 화면의 눈금이
  /// 어긋나지 않는다.
  final List<double> ticks;

  /// `전체` 그래프의 스크롤·선택 상태. 머리의 숫자가 이걸 보고 평균과 하루
  /// 값을 오간다. (#1018)
  final PeriodChartSelection selection;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 이번 주(꺾은선)는 스크롤도 선택도 없다 — 일곱 칸이 이미 한 화면이다.
    final bool selectable = !weekly;
    // 카드의 빈 곳을 누르면 고른 날이 풀려 다시 하루 평균이 뜬다 (회원 앱
    // #1123). 막대·점은 자기 탭을 먼저 받으므로 이 손짓은 그 밖의 자리에만
    // 닿는다.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => selection.select(null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListenableBuilder(
            listenable: selection,
            builder: (BuildContext context, Widget? _) {
              // 이번 주도 점을 골라 그날 값을 볼 수 있다 (회원 앱 #1122).
              // 스크롤이 없을 뿐, 머리 숫자가 평균과 하루를 오가는 규칙은
              // `전체` 와 같다.
              final int? picked = selection.selected;
              // 평소에는 **보이는 구간의** 평균, 날을 고르면 그날의 값.
              // 보이지 않는 날까지 섞은 평균은 지금 화면을 설명하지
              // 못한다. (#1018)
              final double value = picked == null
                  ? (selectable ? selection.averageOf(values) : average)
                  : values[picked];
              final bool over = goal > 0 && value > goal;
              // 칼로리를 볼 때만 탄단지를 곁들인다 — 나트륨·당류는 탄단지로
              // 쪼갤 수 있는 값이 아니다. 날을 고르면 그날의 탄단지, 아니면
              // 기록이 있는 날의 하루 평균이다. (회원 앱 #1121)
              final _Macros? macros = _macrosFor(picked);
              return PeriodChartHeadline(
                selected: picked != null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            picked == null
                                ? '${l.clientPeriodAverage} · $label'
                                : '${DateFormat.yMd(Localizations.localeOf(context).toString()).format(dates[picked])} · $label',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                text: format(value),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: over
                                      ? AppColors.overTarget
                                      : AppColors.foreground,
                                ),
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: ' / ${format(goal)} $unit',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
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
                    if (macros != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.md),
                      _MacroDetail(macros: macros, format: format),
                    ],
                  ],
                ),
              );
            },
          ),
          // 머리와 그래프 사이의 구분선도 간격도 두지 않는다 (회원 앱 #1123).
          // `전체` 는 그 빈 칸을 그래프가 들고 있어(topGap) 고른 막대의
          // 세로선이 머리 카드까지 닿는다.
          SizedBox(height: weekly ? 14 : 0),
          if (weekly)
            Builder(
              builder: (BuildContext context) {
                final days = <String>[
                  for (final DateTime d in dates) _weekdayLabel(l, d),
                ];
                final today = _todayIndexIn(dates);
                return ListenableBuilder(
                  listenable: selection,
                  builder: (BuildContext context, Widget? _) =>
                      MetricTrendChart(
                        values: values,
                        dayLabels: days,
                        goal: goal,
                        ticks: ticks,
                        selectedIndex: selection.selected,
                        onSelected: selection.select,
                        // 선은 오늘까지만 잇는다. 아직 오지 않은 요일의 0 이
                        // 급락처럼 보이면 안 된다.
                        todayIndex: today,
                        // 카드 머리의 지표 이름으로 시작한다 — 음성 안내에서도
                        // 이 그래프가 무엇의 것인지가 먼저 들린다(#972).
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
                        // 남는 자리는 그래프가 쓴다 — 세 화면의 카드 높이를
                        // 같게 두면서 빈 칸을 만들지 않는다. (회원 앱 #1124)
                        height: 105,
                      ),
                );
              },
            )
          else
            // 쌓은 색이 무엇을 뜻하는지는 카드 머리의 탄단지 줄이 말한다 —
            // 그래프 아래 범례는 뺐다 (#1167). 한 카드가 같은 말을 두 번 하지
            // 않는다.
            _PeriodBars(
              values: values,
              logged: logged,
              dates: dates,
              goal: goal,
              unit: unit,
              label: label,
              format: format,
              selection: selection,
              days: days,
            ),
        ],
      ),
    );
  }

  /// 머리 숫자 옆에 붙일 탄단지. [picked] 이 있으면 그날 값, 없으면 기록이
  /// 있는 날의 하루 평균이다. 칼로리를 보고 있지 않거나(나트륨·당류) 서버가
  /// 영양을 주지 않은 기간이면 null 이라 아무것도 붙지 않는다.
  _Macros? _macrosFor(int? picked) {
    final List<ClientDietDay>? all = days;
    if (metric != _Metric.calories || all == null) return null;
    if (picked != null) {
      if (picked >= all.length) return null;
      final ClientDietDay d = all[picked];
      return d.hasMacros
          ? _Macros(carbs: d.carbsG, protein: d.proteinG, fat: d.fatG)
          : null;
    }
    final List<ClientDietDay> logged = all
        .where((ClientDietDay d) => d.hasMacros)
        .toList();
    if (logged.isEmpty) return null;
    double avg(double Function(ClientDietDay) of) =>
        logged.fold<double>(0, (double a, ClientDietDay d) => a + of(d)) /
        logged.length;
    return _Macros(
      carbs: avg((ClientDietDay d) => d.carbsG),
      protein: avg((ClientDietDay d) => d.proteinG),
      fat: avg((ClientDietDay d) => d.fatG),
    );
  }
}

/// 머리 숫자 옆의 탄단지 한 덩어리. 막대를 쌓은 색을 그대로 써서, 예전 그래프
/// 아래 범례가 하던 말(어느 색이 무엇인지)까지 여기서 함께 한다. (회원 앱 #1121)
class _Macros {
  const _Macros({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;
}

class _MacroDetail extends StatelessWidget {
  const _MacroDetail({required this.macros, required this.format});

  final _Macros macros;
  final String Function(num) format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<(String, double, Color)> rows = <(String, double, Color)>[
      (l.metricCarbs, macros.carbs, AppColors.macroCarbs),
      (l.metricProtein, macros.protein, AppColors.macroProtein),
      (l.metricFat, macros.fat, AppColors.macroFat),
    ];
    return Column(
      key: const ValueKey<String>('client-diet-period-macros'),
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (String label, double value, Color color) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  // `204g` — 소수점은 버린다. 옆의 머리 숫자가 주인공이고 이
                  // 줄은 곁들이다. (회원 앱 `_macroGrams`)
                  '${value.round()}g',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
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
    required this.selection,
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

  /// 스크롤 위치와 고른 날. 카드 머리의 숫자가 같은 상태를 본다. (#1018)
  final PeriodChartSelection selection;

  /// [i] 번째 칸의 원본. 칼로리를 보고 있지 않으면 null 이다.
  ClientDietDay? _dayAt(int i) {
    final List<ClientDietDay>? source = days;
    if (source == null || i >= source.length) return null;
    return source[i];
  }

  /// 아직 오지 않은 날인가. (회원 앱 #950)
  ///
  /// 기록하지 않은 것이 아니라 **기록할 수 없는** 날이다. 둘을 같은 말로 그리면
  /// 한 달을 훑으며 "며칠을 빠뜨렸나" 를 셀 때 미래의 빈 칸까지 빠뜨린 날처럼
  /// 읽힌다 — 달 초에는 그 수가 스무 날이 넘는다.
  bool _isPending(int i) {
    final DateTime d = dates[i];
    return DateTime(d.year, d.month, d.day).isAfter(todayKst());
  }

  /// 툴팁과 **같은 내용**을 한 줄짜리 시맨틱 라벨로. 색 사각형(`WidgetSpan`)은
  /// 빼고 줄바꿈은 쉼표로 바꾼다 — 음성 안내는 줄을 나누어 읽지 않는다.
  String _tipText(
    AppLocalizations l,
    DateFormat dayFormat,
    int i,
    bool hasGoal,
  ) => TextSpan(children: _tipSpans(l, dayFormat, i, hasGoal))
      .toPlainText(includePlaceholders: false)
      .split('\n')
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .join(', ');

  /// 색 사각형 하나 — 툴팁 줄 앞에 붙는 범례다.
  InlineSpan _swatch(Color color) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        // 9px 네모라 모서리도 그만큼 작다 — 회원 앱과 같은 2 다.
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  /// 한 막대의 툴팁 내용 — 회원 앱 식단 탭 기간 막대와 같은 구조다.
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
    // 아직 오지 않은 날과 지나갔는데 비운 날은 다른 말이다(회원 앱 #950).
    if (_isPending(i)) {
      spans.add(TextSpan(text: l.chartNotYet));
      return spans;
    }
    // 기록이 없는 날은 0 이 아니라 '기록 없음' 이다. 0 으로 적으면 굶은 날과
    // 적지 않은 날이 같은 말이 된다.
    if (!logged[i] || value <= 0) {
      spans.add(TextSpan(text: l.chartNoRecord));
      return spans;
    }
    spans.add(_swatch(over ? AppColors.overTarget : AppColors.dietChart));
    spans.add(TextSpan(text: '$label   ${format(value)} $unit'));
    // 칼로리 뒤에는 그 칼로리가 어디서 왔는지를 적는다 — 숫자 하나만 보고는
    // 같은 2,000kcal 이 밥에서 왔는지 기름에서 왔는지 알 수 없다.
    final ClientDietDay? day = _dayAt(i);
    if (day != null && day.hasMacros) {
      for (final ({Color color, String label, double grams}) m
          in <({Color color, String label, double grams})>[
            (
              color: AppColors.macroCarbs,
              label: l.metricCarbs,
              grams: day.carbsG,
            ),
            (
              color: AppColors.macroProtein,
              label: l.metricProtein,
              grams: day.proteinG,
            ),
            (color: AppColors.macroFat, label: l.metricFat, grams: day.fatG),
          ]) {
        spans.add(const TextSpan(text: '\n'));
        spans.add(_swatch(m.color));
        spans.add(TextSpan(text: '${m.label}   ${format(m.grams)} g'));
      }
    }
    // 막대가 왜 빨간지를 색이 아니라 글로도 말한다.
    if (over) {
      spans.add(
        TextSpan(
          text: '\n${l.chartOverGoal(format(value - goal), unit)}',
          style: const TextStyle(color: AppColors.overTarget),
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
    // 카드 높이를 오늘·이번 주와 같게 맞추기 위한 값이다 (회원 앱 #1124) —
    // 여기서 1px 을 바꾸면 `전체` 카드 높이가 그만큼 달라진다.
    const double chartHeight = 109;
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
    // 회원 앱 기간 막대의 툴팁 상자 — 옅은 회색 바탕에 실선 테두리.
    final BoxDecoration tipDecoration = BoxDecoration(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderStrong),
      boxShadow: kCardShadow,
    );

    return Semantics(
      container: true,
      label: empty
          ? chartSemanticsLabel(l, title: label, points: const <String>[])
          : null,
      child: ExcludeSemantics(
        excluding: empty,
        child: ListenableBuilder(
          listenable: selection,
          builder: (BuildContext context, Widget? _) => PeriodScrollChart(
            count: values.length,
            height: chartHeight,
            selectedIndex: selection.selected,
            onSelected: selection.select,
            onVisibleRangeChanged: selection.setVisible,
            // 목표치는 왼쪽 칸에 두 줄로 적는다 (#1071).
            goalBottom: hasGoal
                ? chartHeight * (goal / maxValue).clamp(0.0, 1.0)
                : null,
            goalLabel: '${l.clientPeriodGoal}\n${format(goal)}',
            // 머리 카드와 막대 사이의 빈 칸 — 고른 날의 세로선이 여기까지
            // 올라와 회색 카드에 닿는다 (회원 앱 #1123).
            topGap: 14,
            // 날짜만 적으면 `26`, `9` 가 무슨 날인지 알 수 없다 — 달을 함께
            // 적는다 (회원 앱 #1123).
            labelBuilder: (int i) =>
                i % labelStep == 0 ? '${dates[i].month}/${dates[i].day}' : '',
            calloutBuilder: (BuildContext context, int i) =>
                const SizedBox.shrink(),
            barBuilder: (BuildContext context, int i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              // 툴팁은 올려야 보인다. 같은 내용을 시맨틱 라벨로도 준다 — 막대
              // 하나가 며칠 얼마인지는 이 노드 말고는 음성 안내에 나올 데가
              // 없다(#972).
              child: Semantics(
                label: _tipText(l, dayFormat, i, hasGoal),
                child: Tooltip(
                  key: Key('client-diet-bar-$i'),
                  richMessage: TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                      height: 1.3,
                    ),
                    children: _tipSpans(l, dayFormat, i, hasGoal),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: tipDecoration,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _MacroBar(
                      height:
                          chartHeight * (values[i] / maxValue).clamp(0.0, 1.0),
                      day: _dayAt(i),
                      logged: logged[i],
                      pending: _isPending(i),
                      // 목표를 넘긴 날은 **통으로 빨강** 한 색이다 (회원 앱
                      // #1352) — 같은 카드의 나트륨·당류가 초과를 한 색으로
                      // 말하는데 칼로리만 초과의 생김새가 다르면, 눈이 지표마다
                      // 다른 문법을 다시 배워야 한다.
                      over: hasGoal && values[i] > goal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    this.pending = false,
  });

  final double height;
  final ClientDietDay? day;

  /// 그날 기록이 있었는가. 없으면 색 없는 그루터기다.
  final bool logged;

  /// 아직 오지 않은 날인가. 지나간 빈 날의 그루터기보다 **더 옅게** 그린다 —
  /// 둘을 같은 그림으로 두면 달 초에 스무 날 넘는 미래가 전부 '빠뜨린 날' 로
  /// 읽힌다. (회원 앱 #950)
  final bool pending;

  /// 목표를 넘긴 날인가. 넘긴 날은 쌓지 않고 한 색으로 칠한다.
  final bool over;

  @override
  Widget build(BuildContext context) {
    // 회원 앱 기간 막대와 같은 3 이다 — 6 은 좁은 칸에서 막대 끝이 반원처럼
    // 뭉뚱그려져 높이를 읽기 어려웠다.
    const BorderRadius radius = BorderRadius.vertical(top: Radius.circular(3));
    final ClientDietDay? d = day;
    if (pending) {
      // 아직 오지 않은 날은 **빈 트랙**이다. 지나간 빈 날과 같은 그루터기를
      // 그리면 둘이 구분되지 않는다.
      return Container(
        height: 2,
        decoration: const BoxDecoration(
          color: AppColors.border,
          borderRadius: radius,
        ),
      );
    }
    final double total = d == null
        ? 0
        : d.carbsKcal + d.proteinKcal + d.fatKcal;
    // 목표를 넘긴 날은 **통으로 빨강** 한 색이다 (회원 앱 #1352). 탄단지를
    // 빨강 세 단계로 쌓아 봤지만(회원 앱 #1201), 같은 카드의 나트륨·당류는
    // 초과를 한 색으로 말하고 있어 칼로리만 초과의 생김새가 달랐다. 넘기지
    // 않은 날은 지금처럼 탄·단·지 남색 세 단계로 쌓는다.
    if (over || d == null || !d.hasMacros || total <= 0) {
      // 높이가 바뀔 때 애니메이션하지 않는다 — 기간을 옮길 때마다 서른 칸이
      // 함께 자라나면, 값을 읽으려는 사람이 그림이 멈추기를 기다려야
      // 한다. (#1027)
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: !logged
              // 기록이 없는 날은 색이 없다 — 0 으로 칠하면 '적지 않은 날' 이
              // '0kcal 먹은 날' 이 된다.
              ? AppColors.borderStrong
              : over
              ? AppColors.overTarget.withValues(alpha: 0.85)
              // 목표 안쪽 막대는 [AppColors.dietChart] — 이 앱의 브랜드
              // 남색이다. 한때 초록이었지만(#1027) 초록은 `정상` 으로 읽혀
              // 목표에 한참 못 미친 날까지 괜찮다고 말해 걷어냈다(#1168).
              : AppColors.dietChart.withValues(alpha: 0.85),
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
    final List<({Color color, double kcal})>
    parts = <({Color color, double kcal})>[
      // 어느 영양소로도 설명되지 않는 칼로리. 반올림 때문에 생기는
      // 실오라기는 그리지 않는다 — 1% 를 넘을 때만 자리를 준다.
      if (rest / basis > 0.01) (color: AppColors.inputBackground, kcal: rest),
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
          // 식단 카드 전체가 초록 계열이다 — 고른 지표 버튼도 같은 색으로
          // 맞춘다(#1025).
          color: active
              ? AppColors.dietChart.withValues(alpha: 0.12)
              : AppColors.inputBackground,
          borderRadius: const BorderRadius.all(AppRadius.pill),
          border: Border.all(
            color: active
                ? AppColors.dietChart.withValues(alpha: 0.35)
                : const Color(0x00000000),
          ),
        ),
        child: Material(
          color: const Color(0x00000000),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? AppColors.dietChart
                      : AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
