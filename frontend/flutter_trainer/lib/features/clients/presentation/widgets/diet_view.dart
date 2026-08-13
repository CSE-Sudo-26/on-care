import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show weekdayLabels;
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
          _NutritionSummary(client: client),
          if (client.sodiumWeek.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _SodiumTrendCard(client: client),
          ],
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

/// "오늘 영양 요약" — nutrition tiles, warning-styled when
/// over target.
class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.dietTodaySummary,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              MetricTile(
                label: l.metricCalories,
                value: client.calories,
                unit: 'kcal',
                color: AppColors.accentDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: l.metricSodium,
                value: client.sodiumMg,
                unit: 'mg',
                // Neutral base like the other tiles — orange comes only
                // from `warn` when the target is exceeded.
                color: AppColors.accentDark,
                warn: client.sodiumMg > sodiumTargetMg,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: l.metricSugar,
                value: client.sugarG,
                unit: 'g',
                // Navy base like the other tiles — orange only when over.
                color: AppColors.accentDark,
                warn: client.sugarOverBudget,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              MetricTile(
                label: l.metricCarbs,
                value: client.carbsG,
                unit: 'g',
                color: AppColors.accentDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: l.metricProtein,
                value: client.proteinG,
                unit: 'g',
                color: AppColors.accentDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: l.metricFat,
                value: client.fatG,
                unit: 'g',
                color: AppColors.accentDark,
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

  /// 요일 라벨은 로케일을 따르므로 const 로 둘 수 없다. (#501)
  static List<String> _weekdayShort(AppLocalizations l) => weekdayLabels(l);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
        _weekdayShort(l)[today.subtract(Duration(days: i)).weekday - 1],
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Expanded(
                child: Text(
                  l.dietSodiumTrend,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (avg != null)
                Text(
                  l.dietAverageMg(avg),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtleForeground,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 88,
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
                ? l.dietSodiumOverDays(overDays, sodiumTargetMg)
                : l.dietSodiumAllWithin(sodiumTargetMg),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: overDays > 0 ? AppColors.overTarget : AppColors.success,
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
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 12,
          height: h,
          decoration: BoxDecoration(
            color: over ? AppColors.overTarget : AppColors.accent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
      ],
    );
  }
}

/// A single meal record card with calories, sodium, and macronutrients.
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
