import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';

/// The 식단 sub-tab: today's nutrition summary (칼로리/나트륨/당류),
/// per-meal records, and a conditional AI comment.
class DietView extends ConsumerWidget {
  /// Creates the diet view for [client].
  const DietView({super.key, required this.client});

  /// The client whose diet is shown (carries today's totals).
  final TrainerClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diet = ref.watch(clientDietProvider(client.id));

    return diet.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text(
          '식단을 불러오지 못했어요',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
      ),
      data: (meals) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          _NutritionSummary(client: client),
          if (client.sodiumWeek.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _SodiumTrendCard(client: client),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final meal in meals) ...<Widget>[
            _MealCard(entry: meal),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xs),
          _AiComment(client: client),
        ],
      ),
    );
  }
}

/// "오늘 영양 요약" — 칼로리 / 나트륨 / 당류 tiles, warning-styled when
/// over target.
class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '오늘 영양 요약',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              MetricTile(
                label: '칼로리',
                value: client.calories,
                unit: 'kcal',
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: '나트륨',
                value: client.sodiumMg,
                unit: 'mg',
                // Neutral base like the other tiles — orange comes only
                // from `warn` when the target is exceeded.
                color: AppColors.accentDark,
                warn: client.sodiumMg > sodiumTargetMg,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: '당류',
                value: client.sugarG,
                unit: 'g',
                // Blue base like the other tiles — orange only when over.
                color: AppColors.accentDark,
                warn: client.sugarG > sugarTargetG,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "최근 7일 나트륨 추이" — a mini bar chart of the last week's daily
/// sodium (월→일) with the target line, average, and over-days count so
/// the trainer sees the pattern, not just today.
class _SodiumTrendCard extends StatelessWidget {
  const _SodiumTrendCard({required this.client});

  final TrainerClient client;

  static const List<String> _weekdayShort = <String>[
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  @override
  Widget build(BuildContext context) {
    final week = client.sodiumWeek;
    final maxMg = <int>[
      ...week,
      sodiumTargetMg,
    ].reduce((a, b) => a > b ? a : b);
    final overDays = client.sodiumOverDays;
    final avg = client.sodiumWeekAvg;

    // The series ends at today (last entry == today's total), so label
    // each bar with its own weekday counting back from today — a fixed
    // 월→일 axis would mislabel every day the tab is opened on a
    // non-Sunday.
    final today = DateTime.now();
    final labels = <String>[
      for (var i = week.length - 1; i >= 0; i--)
        _weekdayShort[today.subtract(Duration(days: i)).weekday - 1],
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '최근 7일 나트륨 추이',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (avg != null)
                Text(
                  '평균 ${avg}mg',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtleForeground,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var i = 0; i < week.length; i++)
                  Expanded(
                    child: _TrendBar(
                      label: labels[i],
                      value: week[i],
                      maxValue: maxMg,
                      over: week[i] > sodiumTargetMg,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            overDays > 0
                ? '지난 7일 중 $overDays일 목표(${sodiumTargetMg}mg)를 초과했어요.'
                : '지난 7일 모두 목표(${sodiumTargetMg}mg) 이내예요. 좋아요!',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: overDays > 0 ? AppColors.warning : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.over,
  });

  final String label;
  final int value;
  final int maxValue;
  final bool over;

  @override
  Widget build(BuildContext context) {
    // Reserve room for the two text rows; the bar fills the rest.
    const barMax = 52.0;
    final h = maxValue == 0 ? 0.0 : (value / maxValue) * barMax;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 12,
          height: h,
          decoration: BoxDecoration(
            color: over ? AppColors.warning : AppColors.accent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
      ],
    );
  }
}

/// A single meal record card (아침/점심/저녁 badge, foods, kcal, sodium).
class _MealCard extends StatelessWidget {
  const _MealCard({required this.entry});

  final ClientDietEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.accentSurface,
                  borderRadius: BorderRadius.all(AppRadius.pill),
                ),
                child: Text(
                  entry.meal,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${entry.calories} kcal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry.items,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '나트륨 ${entry.sodiumMg}mg',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.subtleForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// "✦ AI 분석" comment — flips wording on the sodium target.
class _AiComment extends StatelessWidget {
  const _AiComment({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final over = client.sodiumOverBudget;
    final sodiumMg = client.sodiumMg;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '✦ AI 분석',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            over
                ? '나트륨이 목표치를 ${sodiumMg - sodiumTargetMg}mg 초과했어요. '
                      '오늘 운동 루틴에 유산소를 추가하면 도움이 돼요.'
                : '오늘 식단은 균형이 잘 맞아요. 현재 루틴을 유지하세요.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
