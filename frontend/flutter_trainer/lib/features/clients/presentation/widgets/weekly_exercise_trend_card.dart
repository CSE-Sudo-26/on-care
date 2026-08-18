import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

class WeeklyExerciseTrendCard extends StatefulWidget {
  const WeeklyExerciseTrendCard({
    super.key,
    required this.week,
    required this.onRetry,
  });

  final AsyncValue<ClientExerciseWeek> week;
  final VoidCallback onRetry;

  @override
  State<WeeklyExerciseTrendCard> createState() =>
      _WeeklyExerciseTrendCardState();
}

class _WeeklyExerciseTrendCardState extends State<WeeklyExerciseTrendCard> {
  bool _showCalories = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SectionCard(
      title: l.clientTrendTitle,
      icon: Icons.monitor_heart_outlined,
      dense: true,
      child: widget.week.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => EmptyHint(
          message: l.clientTrendLoadFailed,
          action: ActionButton(
            key: const ValueKey<String>('weekly-exercise-retry'),
            label: l.actionRetry,
            onPressed: widget.onRetry,
          ),
        ),
        data: (week) => Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: l.clientTrendWorkoutCount,
                    value: '${week.workoutCount}',
                    unit: l.unitTimes,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: l.clientTrendWorkoutMinutes,
                    value: '${week.totalMinutes}',
                    unit: l.unitMinutes,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: l.clientTrendCaloriesBurned,
                    value: '${week.totalCalories}',
                    unit: l.unitKcal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l.clientTrendSegmentTime),
                    icon: const Icon(Icons.schedule, size: 14),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l.metricCalories),
                    icon: const Icon(
                      Icons.local_fire_department_outlined,
                      size: 14,
                    ),
                  ),
                ],
                selected: {_showCalories},
                onSelectionChanged: (selected) =>
                    setState(() => _showCalories = selected.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DailyBars(
              labels: week.dayLabels,
              values: _showCalories ? week.dailyCalories : week.dailyMinutes,
              unit: _showCalories ? l.unitKcal : l.unitMinutes,
              color: _showCalories ? AppColors.brandOrange : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.subtleForeground,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Text.rich(
        TextSpan(
          text: value,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          children: [
            TextSpan(
              text: ' $unit',
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({
    required this.labels,
    required this.values,
    required this.unit,
    required this.color,
  });

  final List<String> labels;
  final List<int> values;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final count = math.min(labels.length, values.length);
    final maxValue = values.take(count).fold<int>(0, math.max);
    return SizedBox(
      height: 128,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < count; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[index] == 0 ? '-' : '${values[index]}$unit',
                      style: const TextStyle(
                        color: AppColors.subtleForeground,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: values[index] == 0
                          ? 3
                          : 72 * values[index] / math.max(maxValue, 1),
                      decoration: BoxDecoration(
                        color: values[index] == 0
                            ? AppColors.borderStrong
                            : color.withValues(alpha: 0.82),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      labels[index],
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
