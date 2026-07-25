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
