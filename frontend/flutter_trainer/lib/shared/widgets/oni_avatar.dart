import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';

/// The On-Care mascot ("Oni") — a teal gradient disc with two eyes and a
/// smile. Adopted from the user app's Figma redesign kit
/// (frontend/flutter design_system/figma) so both apps present the same
/// AI identity; reimplemented here because the trainer app doesn't
/// import the user app package.
class OniAvatar extends StatelessWidget {
  /// Creates the mascot at [size] logical pixels.
  const OniAvatar({super.key, this.size = 36, this.shadow = true});

  /// Diameter.
  final double size;

  /// Whether to render the soft blue drop shadow.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.accent, AppColors.accentDark],
        ),
        boxShadow: shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.58),
          painter: _OniFacePainter(AppColors.accentForeground),
        ),
      ),
    );
  }
}

class _OniFacePainter extends CustomPainter {
  _OniFacePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0; // viewBox is 24×24
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(8.5 * s, 10 * s), 1.5 * s, fill);
    canvas.drawCircle(Offset(15.5 * s, 10 * s), 1.5 * s, fill);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final Path smile = Path()
      ..moveTo(8.5 * s, 14.5 * s)
      ..quadraticBezierTo(12 * s, 17 * s, 15.5 * s, 14.5 * s);
    canvas.drawPath(smile, stroke);
  }

  @override
  bool shouldRepaint(covariant _OniFacePainter oldDelegate) =>
      oldDelegate.color != color;
}
