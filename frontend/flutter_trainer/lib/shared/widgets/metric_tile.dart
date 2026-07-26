import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// A nutrition metric tile (칼로리/나트륨/당류) shared by the 식단
/// sub-tab and the AI 루틴 tab's diet summary. Neutral [color] base;
/// flips to the warning orange (+ "⚠ 초과" suffix) when [warn].
class MetricTile extends StatelessWidget {
  /// Creates a metric tile.
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.warn = false,
  });

  /// Metric name (칼로리 …).
  final String label;

  /// Today's value.
  final int value;

  /// Unit suffix (kcal / mg / g).
  final String unit;

  /// Base value color when not over target.
  final Color color;

  /// Whether the metric exceeded its target.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: warn
              ? AppColors.warning.withValues(alpha: 0.08)
              : AppColors.accentSurface,
          borderRadius: const BorderRadius.all(AppRadius.md),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.subtleForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: warn ? AppColors.warning : color,
              ),
            ),
            Text(
              warn ? '$unit ⚠ 초과' : unit,
              style: TextStyle(
                fontSize: 9,
                fontWeight: warn ? FontWeight.w700 : FontWeight.w400,
                color: warn ? AppColors.warning : AppColors.subtleForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
