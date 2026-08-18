import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// A small icon followed by text, both in the same colour.
///
/// The console used to type its markers straight into the string —
/// `'✦ AI'`, `'✓ 전송됨'`. Those characters are only drawn if the platform
/// happens to load a fallback font that carries them; on Flutter web they
/// come out as 두부 boxes. A `Material` icon is part of the app bundle, so
/// it renders the same everywhere.
class IconLabel extends StatelessWidget {
  /// Creates an icon + label pair.
  const IconLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.fontSize = 10.5,
    this.fontWeight = FontWeight.w700,
    this.iconSize,
    this.textAlign,
  });

  /// Marker drawn ahead of [label].
  final IconData icon;

  /// The text.
  final String label;

  /// Colour of both parts.
  final Color color;

  /// Label size.
  final double fontSize;

  /// Label weight.
  final FontWeight fontWeight;

  /// Icon size; defaults to [fontSize] + 2 so the two stay in proportion.
  final double? iconSize;

  /// Alignment for a label that wraps.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: iconSize ?? fontSize + 2, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
