import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Semantic weight of a [StatCard]'s number.
enum StatTone {
  /// Ordinary information.
  neutral,

  /// Something is owed and the trainer has to act — navy. NOT red: red
  /// means a target was exceeded, and an unanswered message isn't that.
  info,

  /// A target was exceeded — red, same as the member app.
  alert,

  /// Worth a look but not urgent — orange.
  warn,

  /// On track — green.
  positive,

  /// 고객 상태 등급의 중간 단계(주의 고객) — 주황. [alert]/[warn] 은 이미
  /// 빨강(#690)이라, 주의와 이탈 위험을 한 행에서 나란히 보여줄 때는 이
  /// 톤을 쓴다.
  caution,
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
    StatTone.info => AppColors.primary,
    StatTone.alert => AppColors.overTarget,
    StatTone.warn => AppColors.warning,
    StatTone.positive => AppColors.success,
    StatTone.caution => AppColors.statusCaution,
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
            // Browser text metrics can round the intrinsic Column height
            // down by one physical pixel. Keep a small floor so enlarged
            // labels and hints never paint past the KPI card.
            constraints: const BoxConstraints(minHeight: 124),
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
                          fontSize: 13,
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
                // Fixed height: a baseline-aligned Row has no reliable
                // intrinsic height, and the IntrinsicHeight that keeps the
                // KPI tiles level then sized every card a pixel short.
                SizedBox(
                  height: 34,
                  child: Row(
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hint != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
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
