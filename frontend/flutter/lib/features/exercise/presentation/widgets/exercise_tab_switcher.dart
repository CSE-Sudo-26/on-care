import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// Pill-style segmented control used at the top of the 운동 page.
/// Mirrors the prototype's `TabsList` styling: muted-blue track,
/// white "selected" pill with a subtle shadow.
class ExerciseTabSwitcher extends StatelessWidget {
  const ExerciseTabSwitcher({
    required this.activeIndex,
    required this.onChange,
    super.key,
  });

  final int activeIndex;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.all(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Pill(
              label: l.exExerciseLog,
              icon: Icons.event_outlined,
              selected: activeIndex == 0,
              onTap: () => onChange(0),
            ),
          ),
          Expanded(
            child: _Pill(
              label: l.exGymTab,
              icon: Icons.place_outlined,
              selected: activeIndex == 1,
              onTap: () => onChange(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? AppColors.background : Colors.transparent;
    final shadow = selected
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ]
        : const <BoxShadow>[];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(AppRadius.md),
            boxShadow: shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.foreground),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
