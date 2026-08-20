import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// A titled content card — the console's default container.
///
/// Header is title (+ optional leading icon) on the left and one
/// optional trailing affordance (a "전체 보기" link, a filter) on the
/// right. Pass [dense] for cards inside a split panel where the standard
/// padding wastes width.
class SectionCard extends StatelessWidget {
  /// Creates a section card.
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.dense = false,
    this.padding,
  });

  /// Card heading.
  final String title;

  /// Optional leading icon next to the heading.
  final IconData? icon;

  /// Optional right-aligned affordance.
  final Widget? trailing;

  /// Card body.
  final Widget child;

  /// Tighter padding for narrow hosts.
  final bool dense;

  /// Overrides the body padding entirely.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pad =
        padding ?? EdgeInsets.all(dense ? AppSpacing.md : AppSpacing.lg);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  // 카드 제목도 줄임표 대신 축소다 — 옆의 버튼 줄이 길어지면
                  // 제목이 먼저 잘렸다. (#1004)
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: dense ? AppSpacing.sm : AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// A quiet text button used as a [SectionCard.trailing] affordance
/// ("전체 보기", "자세히").
class CardLink extends StatelessWidget {
  /// Creates the link.
  const CardLink({super.key, required this.label, required this.onTap});

  /// Link text.
  final String label;

  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Centered placeholder for an empty card body.
class EmptyHint extends StatelessWidget {
  /// Creates the hint.
  const EmptyHint({super.key, required this.message, this.icon, this.action});

  /// What to tell the trainer.
  final String message;

  /// Optional glyph above the message.
  final IconData? icon;

  /// Optional recovery action for an error state.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 22, color: AppColors.disabledForeground),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.subtleForeground,
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
