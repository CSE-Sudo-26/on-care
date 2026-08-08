import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';

enum AppBadgeTone { neutral, info, success, warning, error }

class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.tone = AppBadgeTone.neutral,
    super.key,
  });

  final String label;
  final AppBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ({Color bg, Color fg}) colors = switch (tone) {
      AppBadgeTone.info => (
        bg: AppColors.info.withValues(alpha: 0.15),
        fg: AppColors.info,
      ),
      AppBadgeTone.success => (
        bg: AppColors.success.withValues(alpha: 0.15),
        fg: AppColors.success,
      ),
      AppBadgeTone.warning => (
        bg: AppColors.warning.withValues(alpha: 0.15),
        fg: AppColors.warning,
      ),
      AppBadgeTone.error => (
        bg: scheme.errorContainer,
        fg: scheme.onErrorContainer,
      ),
      AppBadgeTone.neutral => (
        bg: scheme.surfaceContainerHighest,
        fg: scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.fg,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
    );
  }
}
