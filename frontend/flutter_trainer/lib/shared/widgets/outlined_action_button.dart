import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/radius.dart';

/// The outlined secondary-action button used across tabs
/// (＋ 새 일정 추가 · ＋ 신규 고객 등록 · 📅 스케줄 등록 …): a rounded
/// border in [color] with a bold label, no fill.
class OutlinedActionButton extends StatelessWidget {
  /// Creates an outlined action button.
  const OutlinedActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.height = 44,
  });

  /// Button caption.
  final String label;

  /// Border + label color.
  final Color color;

  /// Tap handler — `null` renders the button disabled.
  final VoidCallback? onTap;

  /// Button height (defaults to 44).
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
