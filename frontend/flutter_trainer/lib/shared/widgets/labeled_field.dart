import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// A caption above an input, replacing `InputDecoration.labelText`.
///
/// The console's inputs are filled boxes with no visible border. A
/// floating `labelText` on that combination is positioned on the border
/// line — which, with no border drawn, lands on the fill and collides
/// with the box and its hint. Putting the caption on its own line above
/// the field is unambiguous at every text scale and matches how the rest
/// of the console labels things.
class LabeledField extends StatelessWidget {
  /// Creates a labelled field.
  const LabeledField({super.key, required this.label, required this.child});

  /// Caption shown above [child].
  final String label;

  /// The input.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
