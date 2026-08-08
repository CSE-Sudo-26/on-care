import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/colors.dart';

/// Vertically-stacked categorical bar chart. Each x position is a
/// single bar made up of segments (`series`) drawn from bottom up.
/// Series with all-zero values are tolerated and treated as empty
/// slices — the bar is drawn invisible so the weekday label still
/// renders below the empty column.
class AppStackedBarChart extends StatelessWidget {
  const AppStackedBarChart({
    required this.series,
    required this.labels,
    this.unitSuffix = '분',
    super.key,
  });

  /// One entry per stacked layer (e.g. cardio / strength / stretching),
  /// each list the same length as [labels].
  final List<({String name, Color color, List<double> values})> series;

  /// X-axis category labels (e.g. ['월','화','수','목','금','토','일']).
  final List<String> labels;

  /// Suffix appended to each value inside the tooltip — `'30분'`,
  /// `'250kcal'`, etc.
  final String unitSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupCount = labels.length;
    final maxStack = _maxStackedValue();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxStack == 0 ? 80 : (maxStack * 1.2),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: theme.dividerColor.withValues(alpha: 0.25)),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxStack == 0 ? 20 : null,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    value.toInt().toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            tooltipMargin: 8,
            getTooltipColor: (_) =>
                AppColors.foreground.withValues(alpha: 0.92),
            getTooltipItem:
                (
                  BarChartGroupData group,
                  int groupIndex,
                  BarChartRodData rod,
                  int rodIndex,
                ) {
                  final i = group.x;
                  final dayName = (i >= 0 && i < labels.length)
                      ? labels[i]
                      : '';
                  final total = _stackTotalAt(i);
                  final childLines = <TextSpan>[];
                  for (final s in series) {
                    final v = i < s.values.length ? s.values[i] : 0.0;
                    if (v <= 0) continue;
                    childLines.add(
                      TextSpan(
                        text: '\n• ${s.name}  ${_fmt(v)}$unitSuffix',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    );
                  }
                  final headline = total > 0
                      ? '$dayName요일  ${_fmt(total)}$unitSuffix'
                      : '$dayName요일  기록 없음';
                  return BarTooltipItem(
                    headline,
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                    children: childLines,
                  );
                },
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < groupCount; i++)
            BarChartGroupData(x: i, barRods: <BarChartRodData>[_rodAt(i)]),
        ],
      ),
    );
  }

  BarChartRodData _rodAt(int i) {
    final stackItems = <BarChartRodStackItem>[];
    double cursor = 0;
    for (final s in series) {
      final v = i < s.values.length ? s.values[i] : 0.0;
      if (v <= 0) continue;
      stackItems.add(BarChartRodStackItem(cursor, cursor + v, s.color));
      cursor += v;
    }
    return BarChartRodData(
      toY: cursor,
      // Doubled from the legacy 18px so the bars read as solid columns,
      // matching the prototype's `WeeklyActivity` look.
      width: 36,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      rodStackItems: stackItems,
      // Solid fallback colour used when there are no stack items (all
      // zero day) — keeps the rod invisible rather than drawing a
      // bright default.
      color: Colors.transparent,
    );
  }

  double _maxStackedValue() {
    double m = 0;
    for (int i = 0; i < labels.length; i++) {
      final sum = _stackTotalAt(i);
      if (sum > m) m = sum;
    }
    return m;
  }

  double _stackTotalAt(int i) {
    double sum = 0;
    for (final s in series) {
      if (i < s.values.length) sum += s.values[i];
    }
    return sum;
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
