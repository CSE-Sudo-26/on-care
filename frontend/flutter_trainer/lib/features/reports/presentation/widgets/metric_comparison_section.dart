import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/metric_pill.dart';

/// 비교 그래프가 다루는 지표.
///
/// 화면에 보이는 라벨과 분리해 둔다 — 로케일이 내부 키가 되면 영어에서 선택이
/// 깨진다. 순서가 곧 알약 버튼의 순서다.
enum CompareMetric {
  /// 운동 이행률(%).
  workout,

  /// 하루 평균 칼로리(kcal). 막대는 탄·단·지로 쌓는다.
  calories,

  /// 하루 평균 나트륨(mg).
  sodium,

  /// 하루 평균 당류(g).
  sugar,
}

/// 지난 주와 견주는 그래프 — 알약 버튼으로 지표를 갈아 끼운다.
///
/// 예전에는 이행률과 나트륨 **두 그래프가 나란히** 박혀 있었다. 카드의 절반을
/// 쓰면서도 칼로리·당류는 어디에도 없었고, 트레이너가 회원에게 말해야 하는
/// "지난주보다 나아졌나" 는 지표마다 다른 자리에서 답이 났다. 자리 하나를
/// 지표 넷이 돌려 쓰면 같은 눈금에서 같은 방식으로 읽힌다(#1177).
///
/// 칼로리만 막대를 탄·단·지로 쌓는다 — 같은 2,000kcal 이 밥에서 왔는지
/// 기름에서 왔는지는 총량만 봐서는 알 수 없다.
class MetricComparisonSection extends ConsumerStatefulWidget {
  /// Creates the comparison section.
  const MetricComparisonSection({super.key, required this.report});

  final WeeklyReport report;

  @override
  ConsumerState<MetricComparisonSection> createState() =>
      _MetricComparisonSectionState();
}

class _MetricComparisonSectionState
    extends ConsumerState<MetricComparisonSection> {
  CompareMetric _metric = CompareMetric.workout;

  String _label(AppLocalizations l, CompareMetric metric) => switch (metric) {
    CompareMetric.workout => l.reportsMetricWorkout,
    CompareMetric.calories => l.metricCalories,
    CompareMetric.sodium => l.metricSodium,
    CompareMetric.sugar => l.metricSugar,
  };

  String _unit(AppLocalizations l) => switch (_metric) {
    CompareMetric.workout => '%',
    CompareMetric.calories => l.unitKcal,
    CompareMetric.sodium => l.unitMg,
    CompareMetric.sugar => l.unitGram,
  };

  /// 하루 평균. 기록이 있는 날만 센다 — 아직 오지 않은 날을 0 으로 세면 이번
  /// 주가 늘 나아 보인다.
  double? _value(WeeklyReport? report) {
    if (report == null) return null;
    return switch (_metric) {
      CompareMetric.workout => report.completionAvg?.toDouble(),
      CompareMetric.calories => recordedMean(report.caloriesWeek),
      CompareMetric.sodium => report.sodiumAvg?.toDouble(),
      CompareMetric.sugar => recordedMean(report.sugarWeek),
    };
  }

  /// 하루 목표. 운동 이행률에는 넘길 목표가 없다 — 100% 가 곧 끝이다.
  double? get _goal => switch (_metric) {
    CompareMetric.workout => null,
    CompareMetric.calories => calorieTargetKcal.toDouble(),
    CompareMetric.sodium => sodiumTargetMg.toDouble(),
    CompareMetric.sugar => sugarTargetG.toDouble(),
  };

  /// 값이 커지는 것이 좋은 지표인가. 칼로리는 목표에 가까울수록 좋은 값이라
  /// 어느 쪽도 아니다 — 변화량에 색을 입히지 않는다.
  bool? get _higherIsBetter => switch (_metric) {
    CompareMetric.workout => true,
    CompareMetric.sodium || CompareMetric.sugar => false,
    CompareMetric.calories => null,
  };

  /// 그 주의 탄·단·지 하루 평균(g). 하나도 없으면 빈 목록이다.
  List<double> _macros(WeeklyReport? report) {
    if (report == null || _metric != CompareMetric.calories) {
      return const <double>[];
    }
    final means = <double>[
      recordedMean(report.carbsWeek) ?? 0,
      recordedMean(report.proteinWeek) ?? 0,
      recordedMean(report.fatWeek) ?? 0,
    ];
    return means.every((v) => v == 0) ? const <double>[] : means;
  }

  String _format(double value) => switch (_metric) {
    CompareMetric.workout => value.round().toString(),
    CompareMetric.sugar => formatNumber((value * 10).roundToDouble() / 10),
    _ => formatNumber(value.round()),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final report = widget.report;
    final previousStart = report.weekStart.subtract(const Duration(days: 7));
    final previous = ref.watch(
      weeklyReportProvider((client: report.client, weekStart: previousStart)),
    );
    final WeeklyReport? before = previous.valueOrNull;
    final double? current = _value(report);
    final double? last = _value(before);
    final String unit = _unit(l);
    final double? goal = _goal;
    // 눈금 끝은 두 주와 목표를 모두 담는다. 그 주의 최댓값에 맞춰 늘이면
    // 1,916 과 1,138 이 늘 같은 높이에서 조금 다른 그림이 된다.
    final double ceiling = <double>[
      current ?? 0,
      last ?? 0,
      if (goal != null) goal * 1.1,
      if (_metric == CompareMetric.workout) 100,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                l.reportsComparisonTitle(
                  report.isCurrentWeek
                      ? l.reportsThisWeek
                      : l.reportsSelectedWeek,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              );
              final pills = Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final metric in CompareMetric.values)
                    MetricPill(
                      key: ValueKey<String>('compare-metric-${metric.name}'),
                      label: _label(l, metric),
                      selected: metric == _metric,
                      onTap: () => setState(() => _metric = metric),
                    ),
                ],
              );
              // 좁은 카드에서는 제목 아래로 내린다 — 한 줄에 우겨넣으면 알약이
              // 글자 크기를 키운 화면에서 그대로 넘친다.
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    title,
                    const SizedBox(height: AppSpacing.xs),
                    pills,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: title),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: pills),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (previous.hasError)
            Text(
              l.reportsPreviousLoadFailed,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final Widget bars = Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: _CompareBar(
                      key: const ValueKey<String>('compare-bar-previous'),
                      label: l.reportsLastWeek,
                      value: last,
                      ceiling: ceiling,
                      unit: unit,
                      goal: goal,
                      macros: _macros(before),
                      format: _format,
                      emptyLabel: l.reportsDataInsufficient,
                      loading: previous.isLoading,
                      current: false,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _CompareBar(
                      key: const ValueKey<String>('compare-bar-current'),
                      label: report.isCurrentWeek
                          ? l.reportsThisWeek
                          : l.reportsSelectedWeek,
                      value: current,
                      ceiling: ceiling,
                      unit: unit,
                      goal: goal,
                      macros: _macros(report),
                      format: _format,
                      emptyLabel: l.reportsDataInsufficient,
                      loading: false,
                      current: true,
                    ),
                  ),
                ],
              );
              final Widget delta = SizedBox(
                width: 84,
                child: _DeltaBadge(
                  caption: l.reportsCompareWith,
                  current: current,
                  previous: last,
                  unit: _metric == CompareMetric.workout ? '%p' : unit,
                  format: _format,
                  higherIsBetter: _higherIsBetter,
                ),
              );
              final Widget? legend =
                  _metric == CompareMetric.calories &&
                      _macros(report).isNotEmpty
                  ? _MacroLegend(means: _macros(report), unit: l.unitGram)
                  : null;
              // 좁은 카드에서는 범례를 아래로 내리고 막대가 남는 폭을 쓴다.
              // 넓은 카드처럼 막대 폭을 240 으로 묶어 두면 변화량 칸과 합쳐
              // 카드보다 넓어진다.
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(child: bars),
                        const SizedBox(width: AppSpacing.sm),
                        delta,
                      ],
                    ),
                    if (legend != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      legend,
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // 두 주는 붙여 둔다. 카드 폭을 반씩 나눠 가지면 견줄 막대
                  // 둘이 화면 양끝으로 갈라져, 정작 비교가 눈에 들어오지 않는다.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: bars,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // 남는 가운데는 막대의 세 조각이 무엇인지 적는 자리다.
                  Expanded(child: legend ?? const SizedBox.shrink()),
                  const SizedBox(width: AppSpacing.sm),
                  delta,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 한 주의 막대 — 값 · 막대 · 주 이름.
class _CompareBar extends StatelessWidget {
  const _CompareBar({
    super.key,
    required this.label,
    required this.value,
    required this.ceiling,
    required this.unit,
    required this.goal,
    required this.macros,
    required this.format,
    required this.emptyLabel,
    required this.loading,
    required this.current,
  });

  final String label;
  final double? value;
  final double ceiling;
  final String unit;
  final double? goal;

  /// 탄·단·지 하루 평균(g). 비어 있으면 한 색으로 채운다.
  final List<double> macros;

  final String Function(double) format;
  final String emptyLabel;
  final bool loading;

  /// 보고 있는 주. 지난 주보다 진하게 그려 어느 쪽이 지금인지 색으로 읽힌다.
  final bool current;

  /// 막대 영역 높이.
  static const double _plotHeight = 92;

  @override
  Widget build(BuildContext context) {
    final bool over = goal != null && value != null && value! > goal!;
    final double fraction = value == null
        ? 0
        : (value! / ceiling).clamp(0.0, 1.0);
    final Color fill = over
        ? AppColors.overTarget
        : current
        ? AppColors.primary
        : AppColors.aiCardGradientEnd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          loading
              ? '…'
              : value == null
              ? emptyLabel
              : '${format(value!)}$unit',
          maxLines: 1,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: current ? FontWeight.w800 : FontWeight.w700,
            color: value == null
                ? AppColors.disabledForeground
                : over
                ? AppColors.overTarget
                : AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _plotHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 56),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: AppRadius.sm),
                child: SizedBox(
                  // 값이 없는 주는 막대를 그리지 않는다 — 빈 자리에 0 을
                  // 채우면 `기록 없음` 이 `0` 으로 읽힌다.
                  height: value == null
                      ? 0
                      : (_plotHeight * fraction).clamp(3.0, _plotHeight),
                  width: double.infinity,
                  child: macros.isEmpty
                      ? ColoredBox(color: fill)
                      : _MacroStack(means: macros, dim: !current),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            color: current ? AppColors.primary : AppColors.subtleForeground,
          ),
        ),
      ],
    );
  }
}

/// 칼로리 막대를 탄·단·지로 쌓는다. 몫은 **열량 기여분**이다(탄·단 4kcal/g,
/// 지방 9kcal/g) — 그램으로 쌓으면 열량의 절반을 내는 지방이 가장 얇게 그려져
/// 막대 전체가 칼로리를 말하지 않게 된다.
class _MacroStack extends StatelessWidget {
  const _MacroStack({required this.means, required this.dim});

  final List<double> means;

  /// 지난 주는 흐리게 — 색은 같고 무게만 다르다.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final List<double> kcal = <double>[
      means[0] * 4,
      means[1] * 4,
      means[2] * 9,
    ];
    final double total = kcal.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return ColoredBox(
        color: dim ? AppColors.aiCardGradientEnd : AppColors.primary,
      );
    }
    const List<Color> colors = <Color>[
      AppColors.macroCarbs,
      AppColors.macroProtein,
      AppColors.macroFat,
    ];
    return Column(
      // 가로로 늘려야 한다 — 가운데 정렬(기본값)이면 조각마다 폭이 0 이 되어
      // 막대가 통째로 사라진다.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 위에서부터 지방·단백질·탄수화물 순으로 쌓는다 — 아래(바닥)가
        // 탄수화물이라 세 막대를 견줄 때 기준이 흔들리지 않는다.
        for (var i = 2; i >= 0; i--)
          Expanded(
            flex: (kcal[i] * 1000).round().clamp(1, 1 << 30),
            child: ColoredBox(
              color: dim ? colors[i].withValues(alpha: 0.45) : colors[i],
            ),
          ),
      ],
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
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
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
              const SizedBox(width: 5),
              Text(
                '${labels[i]} ${formatNumber(means[i].round())}$unit',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 지난 주 대비 변화 한 칸.
class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({
    required this.caption,
    required this.current,
    required this.previous,
    required this.unit,
    required this.format,
    required this.higherIsBetter,
  });

  final String caption;
  final double? current;
  final double? previous;
  final String unit;
  final String Function(double) format;

  /// null 이면 좋고 나쁨을 가리지 않는다 — 칼로리처럼 목표에 가까울수록 좋은
  /// 지표는 늘거나 줄었다는 사실만 적는다.
  final bool? higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final double? delta = current == null || previous == null
        ? null
        : current! - previous!;
    final Color color = delta == null || higherIsBetter == null
        ? AppColors.mutedForeground
        : (delta >= 0) == higherIsBetter!
        ? AppColors.success
        : AppColors.overTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          caption,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          delta == null
              ? '-'
              : '${delta >= 0 ? '+' : '-'}${format(delta.abs())}$unit',
          textAlign: TextAlign.right,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
