import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
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
    this.trailing,
  });

  final String clientId;

  /// `오늘` 은 이 카드가 아니라 영양 요약 카드가 맡는다.
  final ClientPeriod period;

  /// 카드 제목 줄에 얹을 기간 토글. 영양 요약 카드와 **같은 자리**라, 기간을
  /// 바꿔도 조작이 화면에서 움직이지 않는다.
  final Widget? trailing;

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

  /// 소수 첫째 자리까지만 남기고 정수는 콤마만 붙인다 — 당류 17.8 이 18 로
  /// 반올림돼 하루 뷰와 어긋나지 않도록.
  String _number(num v) {
    if (v != v.roundToDouble()) return v.toStringAsFixed(1);
    return v.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match _) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ClientPeriodKey key = (
      clientId: widget.clientId,
      period: widget.period,
    );
    final AsyncValue<ClientDietPeriod> async = ref.watch(
      clientDietPeriodProvider(key),
    );
    return SectionCard(
      key: const ValueKey<String>('client-diet-period-card'),
      title: l.clientDietTrendTitle,
      icon: Icons.insights_outlined,
      dense: true,
      trailing: widget.trailing,
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
                format: _number,
                metricLabel: _label,
              ),
      ),
    );
  }
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
        _PeriodBars(
          values: values,
          logged: logged,
          dates: dates,
          goal: goal,
          unit: unit,
          label: label,
          format: format,
        ),
      ],
    );
  }
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
  });

  final List<double> values;
  final List<bool> logged;
  final List<DateTime> dates;
  final double goal;
  final String unit;
  final String label;
  final String Function(num) format;

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
                    color: AppColors.borderStrong,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (int i = 0; i < values.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Tooltip(
                          key: Key('client-diet-bar-$i'),
                          message: _tip(l, i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height:
                                chartHeight *
                                (values[i] / maxValue).clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              color: !logged[i]
                                  // 기록이 없는 날은 색이 없다 — 0 으로 칠하면
                                  // '적지 않은 날' 이 '0kcal 먹은 날' 이 된다.
                                  ? AppColors.border
                                  : hasGoal && values[i] > goal
                                  ? AppColors.overTarget.withValues(alpha: 0.85)
                                  : AppColors.primary.withValues(alpha: 0.85),
                              borderRadius: const BorderRadius.vertical(
                                top: AppRadius.xs,
                              ),
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
    );
  }

  /// 막대 하나의 툴팁 — 어느 막대가 며칠인지는 x축 라벨만으로 짚을 수 없다.
  String _tip(AppLocalizations l, int i) {
    final DateTime d = dates[i];
    final String date = '${d.month}/${d.day}';
    if (!logged[i]) return '$date · ${l.chartNoRecord}';
    return '$date · $label ${format(values[i])} $unit';
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
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
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
    );
  }
}
