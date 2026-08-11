import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

class WeeklyExerciseTrendCard extends StatefulWidget {
  const WeeklyExerciseTrendCard({super.key, required this.week});

  final AsyncValue<ClientExerciseWeek> week;

  @override
  State<WeeklyExerciseTrendCard> createState() =>
      _WeeklyExerciseTrendCardState();
}

class _WeeklyExerciseTrendCardState extends State<WeeklyExerciseTrendCard> {
  bool _showCalories = false;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: '이번 주 운동 추이',
    icon: Icons.monitor_heart_outlined,
    dense: true,
    child: widget.week.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const EmptyHint(message: '주간 운동 추이를 불러오지 못했습니다.'),
      data: (week) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '운동 횟수',
                  value: '${week.workoutCount}',
                  unit: '회',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '운동 시간',
                  value: '${week.totalMinutes}',
                  unit: '분',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '소모 칼로리',
                  value: '${week.totalCalories}',
                  unit: 'kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('시간'),
                  icon: Icon(Icons.schedule, size: 14),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('칼로리'),
                  icon: Icon(Icons.local_fire_department_outlined, size: 14),
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
            unit: _showCalories ? 'kcal' : '분',
            color: _showCalories ? AppColors.brandOrange : AppColors.primary,
          ),
        ],
      ),
    ),
  );
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
