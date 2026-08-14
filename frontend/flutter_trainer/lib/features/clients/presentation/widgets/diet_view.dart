import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/nutrition_summary_card.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart' show EmptyHint;

/// The 식단 sub-tab: today's nutrition summary,
/// per-meal records, and a conditional AI comment.
class DietView extends ConsumerWidget {
  /// Creates the diet view for [client].
  const DietView({super.key, required this.client, this.embedded = false});

  /// The client whose diet is shown (carries today's totals).
  final TrainerClient client;

  /// When true, lets the member detail own the single page scroll.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final diet = ref.watch(clientDietProvider(client.id));

    return diet.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyHint(
        message: l.dietLoadFailed,
        icon: Icons.error_outline,
        action: ActionButton(
          key: ValueKey<String>('diet-retry-${client.id}'),
          label: l.actionRetry,
          onPressed: diet.isLoading
              ? null
              : () => ref.invalidate(clientDietProvider(client.id)),
        ),
      ),
      data: (meals) {
        final children = <Widget>[
          NutritionSummaryCard(client: client),
          const SizedBox(height: AppSpacing.md),
          // Nothing logged yet: say so, and withhold the verdict. The
          // summary tiles read 0 either way, and `_AiComment` would call
          // a blank day "균형이 잘 맞아요" — praise for a member who has
          // not recorded a single meal.
          if (meals.isEmpty)
            EmptyHint(message: l.dietEmpty, icon: Icons.restaurant_outlined)
          else ...<Widget>[
            for (final meal in meals) ...<Widget>[
              _MealCard(entry: meal),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.xs),
            _AiComment(client: client),
          ],
        ];
        if (embedded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: children,
        );
      },
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.entry});

  final ClientDietEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${entry.calories} kcal',
                style: const TextStyle(
                  fontSize: 13,
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
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.dietSodiumValue(entry.sodiumMg),
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Text('${l.metricCarbs} ${_grams(entry.carbsG)}g'),
              Text('${l.metricProtein} ${_grams(entry.proteinG)}g'),
              Text('${l.metricFat} ${_grams(entry.fatG)}g'),
            ],
          ),
        ],
      ),
    );
  }
}

String _grams(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// "✦ AI 분석" comment — flips wording on the sodium target.
class _AiComment extends StatelessWidget {
  const _AiComment({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
          IconLabel(
            icon: Icons.auto_awesome,
            label: l.dietAiAnalysis,
            color: AppColors.accent,
            fontSize: 11,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            over
                ? l.dietAiOverSodium(sodiumMg - sodiumTargetMg)
                : l.dietAiBalanced,
            style: const TextStyle(
              fontSize: 13,
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
