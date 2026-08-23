import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/four_week_metric_trend.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/chart_semantics.dart';
import 'package:oncare_trainer/shared/widgets/metric_trend_chart.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 어떤 영양 지표의 주간 추이를 볼지 고르는 식별자.
///
/// 화면에 보이는 라벨과 분리해 둔다 — 로케일이 내부 키가 되면 영어에서
/// 선택이 깨진다.
enum _TrendMetric { calories, sodium, sugar }

/// 칼로리·나트륨·당류 주간 추이 — 선택한 지표 하나를 사용자 앱 홈 탭과 **같은
/// 그림**으로 그린다(#746).
///
/// 눈금은 사용자 앱 `dashboard_content.dart` 의 값을 그대로 쓴다. 지표를 바꿔도
/// 축 바닥이 항상 0 이라 세 그래프를 번갈아 봐도 기준선이 흔들리지 않는다.
class MetricTrendSection extends StatefulWidget {
  const MetricTrendSection({super.key, required this.report});

  final WeeklyReport report;

  @override
  State<MetricTrendSection> createState() => _MetricTrendSectionState();
}

class _MetricTrendSectionState extends State<MetricTrendSection> {
  _TrendMetric _metric = _TrendMetric.calories;

  String _label(AppLocalizations l, _TrendMetric metric) => switch (metric) {
    _TrendMetric.calories => l.metricCalories,
    _TrendMetric.sodium => l.metricSodium,
    _TrendMetric.sugar => l.metricSugar,
  };

  /// 고른 지표의 단위. 4주 추이 막대와 시맨틱 라벨이 **같은 것**을 써야
  /// 그래프와 음성 안내가 서로 다른 단위를 말하지 않는다.
  String _unit(AppLocalizations l) => switch (_metric) {
    _TrendMetric.calories => l.unitKcal,
    _TrendMetric.sodium => l.unitMg,
    _TrendMetric.sugar => l.unitGram,
  };

  /// 선택한 지표의 요일별 값. 계열이 7일이 아니면(구버전 응답) 비워 둔다.
  List<double> get _values {
    final report = widget.report;
    final series = switch (_metric) {
      _TrendMetric.calories => report.caloriesWeek.map((v) => v.toDouble()),
      _TrendMetric.sodium => report.sodiumWeek.map((v) => v.toDouble()),
      _TrendMetric.sugar => report.sugarWeek,
    }.toList(growable: false);
    return series.length == weekdayCount ? series : const <double>[];
  }

  double get _goal => switch (_metric) {
    _TrendMetric.calories => calorieTargetKcal.toDouble(),
    _TrendMetric.sodium => sodiumTargetMg.toDouble(),
    _TrendMetric.sugar => sugarTargetG.toDouble(),
  };

  List<double> get _ticks => switch (_metric) {
    _TrendMetric.calories => const <double>[0, 1500, 2500],
    _TrendMetric.sodium => const <double>[0, 1750, 3500],
    _TrendMetric.sugar => const <double>[0, 25, 50],
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final values = _values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.reportsMetricTrend(_label(l, _metric)),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.subtleForeground,
                ),
              ),
            ),
            for (final metric in _TrendMetric.values) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              _MetricChip(
                key: ValueKey<String>('trend-metric-${metric.name}'),
                label: _label(l, metric),
                selected: metric == _metric,
                onTap: () => setState(() => _metric = metric),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 기록이 하나도 없는 주까지 바닥에 붙은 0 선을 그리면 "기록 없음"이
        // "하루 0kcal" 처럼 읽힌다.
        if (values.isEmpty || values.every((v) => v == 0))
          EmptyHint(
            message: widget.report.isCurrentWeek
                ? l.reportsNoMetricRecords(_label(l, _metric))
                : l.reportsNoLastWeekMetricTrend(_label(l, _metric)),
          )
        else
          MetricTrendChart(
            values: values,
            dayLabels: weekdayLabels(l),
            goal: _goal,
            ticks: _ticks,
            // 지난 주는 이미 다 지났으니 선을 일요일까지 잇되, 그 자리에
            // '오늘' 표시를 붙이지는 않는다.
            todayIndex: widget.report.isCurrentWeek
                ? elapsedWeekdays(nowKst()) - 1
                : weekdayCount - 1,
            markToday: widget.report.isCurrentWeek,
            // 화면 위 제목과 같은 문구로 시작한다 — 음성 안내에서도 이 그래프가
            // 어느 지표의 것인지가 먼저 들린다(#972).
            semanticsLabel: chartSemanticsLabel(
              l,
              title: l.reportsMetricTrend(_label(l, _metric)),
              points: chartSeriesPoints(
                l,
                values: values,
                dayLabels: weekdayLabels(l),
                format: (double v) => '${metricTrendNumber(v)}${_unit(l)}',
                // 이번 주 선은 오늘까지만 잇는다. 아직 오지 않은 요일을 읽으면
                // 화면에 없는 값을 말하게 된다.
                upTo: widget.report.isCurrentWeek
                    ? elapsedWeekdays(nowKst()) - 1
                    : weekdayCount - 1,
              ),
            ),
            goalLabel: l.chartGoalLabel(metricTrendNumber(_goal)),
            formatTick: metricTrendNumber,
          ),
        const Divider(height: AppSpacing.xl, color: AppColors.border),
        FourWeekMetricTrend(
          report: widget.report,
          label: _label(l, _metric),
          values: (WeeklyReport r) => switch (_metric) {
            _TrendMetric.calories => r.caloriesWeek,
            _TrendMetric.sodium => r.sodiumWeek,
            _TrendMetric.sugar => r.sugarWeek,
          },
          goal: _goal,
          unit: _unit(l),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.accentSurface : AppColors.inputBackground,
    borderRadius: const BorderRadius.all(AppRadius.pill),
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.mutedForeground,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
