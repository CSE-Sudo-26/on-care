import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/bar_line_chart.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/metric_pill.dart';

/// 운동 상자가 견주는 값.
enum ExerciseCompareMetric {
  /// 그 주에 태운 열량(kcal).
  burned,

  /// 유산소·근력·스트레칭 시간(분).
  cardio,
  strength,
  stretching,
}

/// 식단 상자가 견주는 값.
enum DietCompareMetric {
  /// 하루 평균 칼로리(kcal). 막대는 탄·단·지로 쌓는다.
  calories,

  /// 하루 평균 나트륨(mg).
  sodium,

  /// 하루 평균 당류(g).
  sugar,
}

/// 이번 주 vs 지난 주 — 운동과 식단을 흰 상자 둘로 나눠 나란히 놓는다.
///
/// 한 상자 안에서는 알약 버튼으로 지표를 갈아 끼우고, 그래프는 `주간 운동
/// 이행률` 과 **같은 그림**(막대 + 꺾은선)이다. 카드마다 다른 막대를 쓰면 같은
/// 화면에서 눈금이 갈린 것처럼 보인다(#1177).
class MetricComparisonSection extends StatelessWidget {
  /// Creates the comparison section.
  const MetricComparisonSection({super.key, required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.reportsComparisonTitle(
              report.isCurrentWeek ? l.reportsThisWeek : l.reportsSelectedWeek,
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final Widget workout = _ExerciseComparisonBox(report: report);
              final Widget diet = _DietComparisonBox(report: report);
              // 좁은 카드에서는 위아래로 쌓는다 — 한 줄에 우겨넣으면 상자 하나가
              // 막대 둘도 못 담는 폭이 된다.
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    workout,
                    const SizedBox(height: AppSpacing.sm),
                    diet,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: workout),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: diet),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 흰 상자 하나 — 제목 · 알약 · 그래프 · 변화량.
class _ComparisonBox extends StatelessWidget {
  const _ComparisonBox({
    required this.title,
    required this.caption,
    required this.pills,
    required this.previous,
    required this.current,
    required this.previousLabel,
    required this.currentLabel,
    required this.format,
    required this.goal,
    required this.segments,
    required this.legend,
    required this.higherIsBetter,
    required this.loading,
    required this.emptyLabel,
    required this.semanticsLabel,
  });

  final String title;

  /// 값이 주 합계인지 하루 평균인지. 두 상자가 다른 기준을 쓰므로 적어 준다.
  final String caption;

  final List<Widget> pills;
  final double? previous;
  final double? current;
  final String previousLabel;
  final String currentLabel;
  final String Function(double) format;

  /// 넘으면 막대가 빨강이 되는 값.
  final double? goal;

  /// 막대를 쌓을 조각(칼로리의 탄·단·지). 없으면 한 색으로 채운다.
  final List<List<BarSegment>?>? segments;

  /// 조각이 무엇인지 적는 줄.
  final Widget? legend;

  final bool? higherIsBetter;
  final bool loading;
  final String emptyLabel;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    // 눈금 끝은 두 주와 목표를 모두 담는다. 그 주의 최댓값에 맞춰 늘이면 두 주가
    // 늘 같은 높이에서 조금 다른 그림이 된다.
    final double ceiling = <double>[
      previous ?? 0,
      current ?? 0,
      if (goal != null) goal! * 1.05,
      1,
    ].reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtleForeground,
                  ),
                ),
              ),
              _DeltaBadge(
                current: current,
                previous: previous,
                format: format,
                higherIsBetter: higherIsBetter,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // 범례는 알약 **오른쪽**에 둔다. 그래프 아래에 있던 때에는 칼로리를
          // 고를 때만 한 줄이 생겨 상자 높이가 달라졌고, 나란히 선 운동 상자와
          // 아래 끝이 어긋났다. 알약 줄은 지표와 무관하게 늘 있는 자리다(#1177).
          Row(
            children: <Widget>[
              Flexible(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: pills,
                ),
              ),
              if (legend != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                // 자리가 좁으면 줄을 접는 대신 글씨를 줄인다 — 접히는 순간
                // 상자 높이가 다시 달라진다.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: legend!,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            BarLineChart(
              values: <double?>[previous, current],
              labels: <String>[previousLabel, currentLabel],
              ceiling: ceiling,
              goal: goal,
              segments: segments,
              format: format,
              emptyLabel: emptyLabel,
              highlightIndex: 1,
              height: 96,
              maxBarWidth: 46,
              semanticsLabel: semanticsLabel,
            ),
        ],
      ),
    );
  }
}

/// 운동 상자 — 소모 칼로리·유산소·근력·스트레칭을 주 합계로 견준다.
class _ExerciseComparisonBox extends ConsumerStatefulWidget {
  const _ExerciseComparisonBox({required this.report});

  final WeeklyReport report;

  @override
  ConsumerState<_ExerciseComparisonBox> createState() =>
      _ExerciseComparisonBoxState();
}

class _ExerciseComparisonBoxState
    extends ConsumerState<_ExerciseComparisonBox> {
  ExerciseCompareMetric _metric = ExerciseCompareMetric.burned;

  String _label(AppLocalizations l, ExerciseCompareMetric metric) =>
      switch (metric) {
        ExerciseCompareMetric.burned => l.clientTrendCaloriesBurned,
        ExerciseCompareMetric.cardio => l.routineTypeCardio,
        ExerciseCompareMetric.strength => l.routineTypeStrength,
        ExerciseCompareMetric.stretching => l.routineTypeStretching,
      };

  double? _value(ClientExercisePeriod? period) {
    if (period == null) return null;
    // 그 주에 아무 기록도 없으면 0 이 아니라 '없음' 이다.
    if (period.days.every((d) => !d.logged)) return null;
    return switch (_metric) {
      ExerciseCompareMetric.burned => period.totalCalories,
      ExerciseCompareMetric.cardio => period.totalCardioMinutes,
      ExerciseCompareMetric.strength => period.totalStrengthMinutes,
      ExerciseCompareMetric.stretching => period.totalStretchingMinutes,
    }.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final report = widget.report;
    ClientPeriodKey keyFor(DateTime week) => (
      clientId: report.client.id,
      period: ClientPeriod.week,
      day: week,
    );
    final week = ref.watch(
      clientExercisePeriodProvider(keyFor(report.weekStart)),
    );
    final before = ref.watch(
      clientExercisePeriodProvider(
        keyFor(report.weekStart.subtract(const Duration(days: 7))),
      ),
    );
    final String unit = _metric == ExerciseCompareMetric.burned
        ? l.unitKcal
        : l.unitMinutes;
    String format(double v) => '${formatNumber(v.round())}$unit';
    return _ComparisonBox(
      title: l.clientTabWorkout,
      caption: l.reportsWeekTotal,
      pills: <Widget>[
        for (final metric in ExerciseCompareMetric.values)
          MetricPill(
            key: ValueKey<String>('compare-exercise-${metric.name}'),
            label: _label(l, metric),
            selected: metric == _metric,
            onTap: () => setState(() => _metric = metric),
          ),
      ],
      previous: _value(before.valueOrNull),
      current: _value(week.valueOrNull),
      previousLabel: l.reportsLastWeek,
      currentLabel: report.isCurrentWeek
          ? l.reportsThisWeek
          : l.reportsSelectedWeek,
      format: format,
      goal: null,
      segments: null,
      legend: null,
      // 운동은 많이 할수록 좋은 값이다.
      higherIsBetter: true,
      loading: week.isLoading || before.isLoading,
      emptyLabel: l.reportsDataInsufficient,
      semanticsLabel: '${l.clientTabWorkout} · ${_label(l, _metric)}',
    );
  }
}

/// 식단 상자 — 칼로리(탄·단·지)·나트륨·당류를 하루 평균으로 견준다.
class _DietComparisonBox extends ConsumerStatefulWidget {
  const _DietComparisonBox({required this.report});

  final WeeklyReport report;

  @override
  ConsumerState<_DietComparisonBox> createState() => _DietComparisonBoxState();
}

class _DietComparisonBoxState extends ConsumerState<_DietComparisonBox> {
  DietCompareMetric _metric = DietCompareMetric.calories;

  String _label(AppLocalizations l, DietCompareMetric metric) =>
      switch (metric) {
        DietCompareMetric.calories => l.metricCalories,
        DietCompareMetric.sodium => l.metricSodium,
        DietCompareMetric.sugar => l.metricSugar,
      };

  /// 하루 평균. 기록이 있는 날만 센다 — 아직 오지 않은 날을 0 으로 세면 이번
  /// 주가 늘 나아 보인다.
  double? _value(WeeklyReport? report) {
    if (report == null) return null;
    return switch (_metric) {
      DietCompareMetric.calories => recordedMean(report.caloriesWeek),
      DietCompareMetric.sodium => report.sodiumAvg?.toDouble(),
      DietCompareMetric.sugar => recordedMean(report.sugarWeek),
    };
  }

  double get _goal => switch (_metric) {
    DietCompareMetric.calories => calorieTargetKcal.toDouble(),
    DietCompareMetric.sodium => sodiumTargetMg.toDouble(),
    DietCompareMetric.sugar => sugarTargetG.toDouble(),
  };

  /// 그 주의 탄·단·지 하루 평균(g). 하나도 없으면 빈 목록이다.
  List<double> _macros(WeeklyReport? report) {
    if (report == null || _metric != DietCompareMetric.calories) {
      return const <double>[];
    }
    final means = <double>[
      recordedMean(report.carbsWeek) ?? 0,
      recordedMean(report.proteinWeek) ?? 0,
      recordedMean(report.fatWeek) ?? 0,
    ];
    return means.every((v) => v == 0) ? const <double>[] : means;
  }

  /// 막대를 쌓을 조각. 몫은 **열량 기여분**이다(탄·단 4kcal/g, 지방 9kcal/g) —
  /// 그램으로 쌓으면 열량의 절반을 내는 지방이 가장 얇게 그려져 막대 전체가
  /// 칼로리를 말하지 않게 된다.
  List<BarSegment>? _segments(WeeklyReport? report) {
    final means = _macros(report);
    if (means.isEmpty) return null;
    return <BarSegment>[
      (value: means[0] * 4, color: AppColors.macroCarbs),
      (value: means[1] * 4, color: AppColors.macroProtein),
      (value: means[2] * 9, color: AppColors.macroFat),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final report = widget.report;
    final previous = ref.watch(
      weeklyReportProvider((
        client: report.client,
        weekStart: report.weekStart.subtract(const Duration(days: 7)),
      )),
    );
    final WeeklyReport? before = previous.valueOrNull;
    final String unit = switch (_metric) {
      DietCompareMetric.calories => l.unitKcal,
      DietCompareMetric.sodium => l.unitMg,
      DietCompareMetric.sugar => l.unitGram,
    };
    String format(double v) => _metric == DietCompareMetric.sugar
        ? '${formatNumber((v * 10).roundToDouble() / 10)}$unit'
        : '${formatNumber(v.round())}$unit';
    final List<double> means = _macros(report);
    return _ComparisonBox(
      title: l.clientTabDiet,
      caption: l.clientPeriodAverage,
      pills: <Widget>[
        for (final metric in DietCompareMetric.values)
          MetricPill(
            key: ValueKey<String>('compare-diet-${metric.name}'),
            label: _label(l, metric),
            selected: metric == _metric,
            onTap: () => setState(() => _metric = metric),
          ),
      ],
      previous: _value(before),
      current: _value(report),
      previousLabel: l.reportsLastWeek,
      currentLabel: report.isCurrentWeek
          ? l.reportsThisWeek
          : l.reportsSelectedWeek,
      format: format,
      goal: _goal,
      segments: <List<BarSegment>?>[_segments(before), _segments(report)],
      legend: means.isEmpty
          ? null
          : _MacroLegend(means: means, unit: l.unitGram),
      // 칼로리는 목표에 가까울수록 좋은 값이라 어느 쪽도 아니다.
      higherIsBetter: _metric == DietCompareMetric.calories ? null : false,
      loading: previous.isLoading,
      emptyLabel: l.reportsDataInsufficient,
      semanticsLabel: '${l.clientTabDiet} · ${_label(l, _metric)}',
    );
  }
}

/// 탄·단·지 하루 평균을 색과 함께 적는다. 막대의 세 조각이 무엇인지 말하는
/// 유일한 자리다.
class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.means, required this.unit});

  final List<double> means;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = <String>[l.metricCarbs, l.metricProtein, l.metricFat];
    const colors = <Color>[
      AppColors.macroCarbs,
      AppColors.macroProtein,
      AppColors.macroFat,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${labels[i]} ${formatNumber(means[i].round())}$unit',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
              if (i < labels.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ),
      ],
    );
  }
}

/// 지난 주 대비 변화 한 칸.
class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({
    required this.current,
    required this.previous,
    required this.format,
    required this.higherIsBetter,
  });

  final double? current;
  final double? previous;
  final String Function(double) format;

  /// null 이면 좋고 나쁨을 가리지 않는다 — 칼로리처럼 목표에 가까울수록 좋은
  /// 지표는 늘거나 줄었다는 사실만 적는다.
  final bool? higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final double? delta = current == null || previous == null
        ? null
        : current! - previous!;
    if (delta == null) return const SizedBox.shrink();
    final Color color = higherIsBetter == null
        ? AppColors.mutedForeground
        : (delta >= 0) == higherIsBetter!
        ? AppColors.success
        : AppColors.overTarget;
    return Text(
      '${delta >= 0 ? '+' : '-'}${format(delta.abs())}',
      maxLines: 1,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}
