import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Compact page-header action. [primary] fills with the navy brand;
/// otherwise it's an outlined, quieter sibling.
///
/// One primary per header — when two actions both fill, neither reads as
/// the main one.
class ActionButton extends StatelessWidget {
  /// Creates a header action.
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.tone,
  });

  /// Button text.
  final String label;

  /// Tap handler; `null` disables the button.
  final VoidCallback? onPressed;

  /// Optional leading glyph.
  final IconData? icon;

  /// Whether this is the filled, main action.
  final bool primary;

  /// Overrides the accent colour (e.g. destructive actions).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.primary;
    final enabled = onPressed != null;
    final fg = primary
        ? AppColors.primaryForeground
        : (enabled ? accent : AppColors.disabledForeground);

    return Material(
      color: primary
          ? (enabled ? accent : AppColors.disabledForeground)
          : Colors.transparent,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.md),
            border: primary
                ? null
                : Border.all(
                    color: enabled
                        ? accent.withValues(alpha: 0.45)
                        : AppColors.borderStrong,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented switch used for in-page view modes (일/주, 내 정보/설정).
class SegmentedSwitch extends StatelessWidget {
  /// Creates a segmented switch.
  const SegmentedSwitch({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  /// Segment labels in order.
  final List<String> labels;

  /// Index of the active segment.
  final int selected;

  /// Called with the tapped index.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < labels.length; i++)
            Semantics(
              button: true,
              selected: selected == i,
              inMutuallyExclusiveGroup: true,
              child: Material(
                color: selected == i ? AppColors.card : Colors.transparent,
                borderRadius: const BorderRadius.all(AppRadius.sm),
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: const BorderRadius.all(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected == i
                            ? AppColors.primary
                            : AppColors.subtleForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
