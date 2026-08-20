import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';

/// 이번 주 vs 지난 주 — 같은 지표를 두 주로 나란히 놓는다.
class WeekComparison extends ConsumerWidget {
  const WeekComparison({super.key, required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final previousStart = report.weekStart.subtract(const Duration(days: 7));
    final previous = ref.watch(
      weeklyReportProvider((client: report.client, weekStart: previousStart)),
    );
    final before = previous.valueOrNull;
    final completionDelta = _delta(report.completionAvg, before?.completionAvg);
    final sodiumDelta = _delta(report.sodiumAvg, before?.sodiumAvg);
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (previous.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (previous.hasError)
            Text(
              l.reportsPreviousLoadFailed,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final charts = <Widget>[
                  _ComparisonMetric(
                    key: const ValueKey<String>('completion-comparison-chart'),
                    label: l.reportsCompletionAvg,
                    current: report.completionAvg,
                    previous: before?.completionAvg,
                    previousLabel: l.reportsLastWeek,
                    currentLabel: report.isCurrentWeek
                        ? l.reportsThisWeek
                        : l.reportsSelectedWeek,
                    maxValue: 100,
                    valueSuffix: '%',
                    delta: completionDelta == null
                        ? null
                        : '${completionDelta >= 0 ? '+' : ''}$completionDelta%p',
                    positive: completionDelta == null || completionDelta >= 0,
                  ),
                  _ComparisonMetric(
                    key: const ValueKey<String>('sodium-comparison-chart'),
                    label: l.reportsAverageSodium,
                    current: report.sodiumAvg,
                    previous: before?.sodiumAvg,
                    previousLabel: l.reportsLastWeek,
                    currentLabel: report.isCurrentWeek
                        ? l.reportsThisWeek
                        : l.reportsSelectedWeek,
                    valueSuffix: 'mg',
                    delta: sodiumDelta == null
                        ? null
                        : '${sodiumDelta >= 0 ? '+' : ''}${sodiumDelta}mg',
                    positive: sodiumDelta == null || sodiumDelta <= 0,
                  ),
                ];
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: <Widget>[
                      charts.first,
                      const SizedBox(height: AppSpacing.sm),
                      charts.last,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: charts.first),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: charts.last),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  static int? _delta(int? current, int? previous) =>
      current == null || previous == null ? null : current - previous;
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    super.key,
    required this.label,
    required this.current,
    required this.previous,
    required this.previousLabel,
    required this.currentLabel,
    required this.valueSuffix,
    required this.delta,
    required this.positive,
    this.maxValue,
  });

  final String label;
  final int? current;
  final int? previous;
  final String previousLabel;
  final String currentLabel;
  final String valueSuffix;
  final String? delta;
  final bool positive;
  final int? maxValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.subtleForeground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          BarSeriesChart(
            title: label,
            values: <int>[previous ?? 0, current ?? 0],
            labels: <String>[previousLabel, currentLabel],
            maxValue: maxValue,
            showValues: true,
            valueSuffix: valueSuffix,
            highlightIndex: 1,
            missingIndices: <int>{
              if (previous == null) 0,
              if (current == null) 1,
            },
          ),
          if (delta != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                delta!,
                style: TextStyle(
                  color: positive ? AppColors.success : AppColors.overTarget,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
