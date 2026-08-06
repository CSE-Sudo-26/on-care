import 'package:flutter/material.dart';

import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';

String _mealLabel(MealType m) => switch (m) {
  MealType.breakfast => '아침',
  MealType.lunch => '점심',
  MealType.dinner => '저녁',
  MealType.snack => '간식',
};

class MealCard extends StatelessWidget {
  const MealCard({required this.entry, this.onTap, super.key});
  final DietEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      outlined: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  _mealLabel(entry.mealType),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                entry.timeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              Text(
                '${entry.totalCalories} kcal',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final f in entry.foods)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(f.name, style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    '${f.calories} kcal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          if (entry.sodiumMg > 0 || entry.sugarG > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                _Pill(
                  label: '나트륨 ${entry.sodiumMg}mg',
                  tone: entry.sodiumMg > 800
                      ? _PillTone.warning
                      : _PillTone.muted,
                ),
                const SizedBox(width: 6),
                _Pill(label: '당류 ${entry.sugarG}g', tone: _PillTone.muted),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _PillTone { muted, warning }

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});
  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg) = switch (tone) {
      _PillTone.warning => (
        AppColors.warning.withValues(alpha: 0.12),
        AppColors.warning,
      ),
      _PillTone.muted => (AppColors.muted, AppColors.mutedForeground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
