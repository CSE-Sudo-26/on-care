import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// A coloured dot followed by a status word (활성 / 휴면 / 영업 중).
///
/// The dot is drawn, not typed. Writing it as a '●'/'○' character left the
/// glyph up to whatever fallback font the platform happened to load — on
/// Flutter web that renders as a 두부 box, because the app's font stack has
/// no geometric-shapes coverage.
class StatusDotLabel extends StatelessWidget {
  /// Creates a status label.
  const StatusDotLabel({
    super.key,
    required this.label,
    required this.color,
    this.filled = true,
  });

  /// The status word.
  final String label;

  /// Colour of both the dot and the text.
  final Color color;

  /// Whether the dot is solid (an on state) or a ring (an off state).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: color, width: 1.2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
