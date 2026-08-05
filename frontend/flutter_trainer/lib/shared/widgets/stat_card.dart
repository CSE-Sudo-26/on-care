import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Semantic weight of a [StatCard]'s number.
enum StatTone {
  /// Ordinary information.
  neutral,

  /// Something is owed / overdue — red.
  alert,

  /// Worth a look but not urgent — orange.
  warn,

  /// On track — green.
  positive,
}

/// A KPI tile: label, big number, unit, and a hint line.
///
/// Every stat card is a **link**, not a readout — a dashboard number the
/// trainer can't act on is decoration. [onTap] should deep-link to the
/// filtered view that explains the number.
class StatCard extends StatelessWidget {
  /// Creates a KPI tile.
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
    this.hint,
    this.tone = StatTone.neutral,
    this.onTap,
  });

  /// Metric name (오늘 예약 …).
  final String label;

  /// The number, already formatted. `-` while loading.
  final String value;

  /// Unit suffix rendered small next to the number (건/명 …).
  final String? unit;

  /// One-line context under the number.
  final String? hint;

  /// Leading glyph.
  final IconData icon;

  /// Semantic colour of the number.
  final StatTone tone;

  /// Where this number leads.
  final VoidCallback? onTap;

  Color get _toneColor => switch (tone) {
    StatTone.neutral => AppColors.foreground,
    StatTone.alert => AppColors.destructive,
    StatTone.warn => AppColors.warning,
    StatTone.positive => AppColors.success,
  };

  Color get _iconColor =>
      tone == StatTone.neutral ? AppColors.primary : _toneColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _iconColor.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.all(AppRadius.sm),
                      ),
                      child: Icon(icon, size: 15, color: _iconColor),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.disabledForeground,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: _toneColor,
                      ),
                    ),
                    if (unit != null) ...<Widget>[
                      const SizedBox(width: 3),
                      Text(
                        unit!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtleForeground,
                        ),
                      ),
                    ],
                  ],
                ),
                if (hint != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.subtleForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
