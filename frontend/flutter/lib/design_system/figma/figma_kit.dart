import 'package:flutter/material.dart';

/// Exact colour tokens lifted from the On-Care Figma (TypeScript) source so the
/// Flutter screens reproduce the redesign 1:1.
///
/// [AppColors] keeps the shared/semantic brand tokens; this palette adds the
/// precise inline tints the Figma uses (label greys, macro-bar colours, delta
/// greens/oranges, banner gradients). Prefer these when matching a screen to
/// the mockup pixel-for-pixel.
class FigmaColors {
  FigmaColors._();

  // Text / ink
  static const Color ink = Color(0xFF1A1A1A); // headings, near-black
  static const Color textMuted = Color(0xFFA0A8B5); // labels / greeting
  static const Color textFaint = Color(0xFFC0CDD6); // inactive tab / minutes
  static const Color textSub = Color(0xFF8A8A9A); // subtitles
  static const Color textBody = Color(0xFF5A6A7A); // coaching body copy

  // Brand
  static const Color primary = Color(0xFF3EAFDF);
  static const Color primaryDeep = Color(0xFF2A8FBD); // FAB gradient end
  static const Color primaryStripe = Color(0xFF2190C4); // card top stripe end
  static const Color oniEnd = Color(0xFF2A9BCA); // Oni avatar gradient end

  // Semantic accents
  static const Color green = Color(0xFF34C9A0); // protein / good bar
  static const Color greenText = Color(0xFF22A882); // good delta text
  static const Color greenTag = Color(0xFF34C782); // coaching 운동 tag
  static const Color orange = Color(0xFFFF953C); // fat bar / warn fill
  static const Color orangeText = Color(0xFFE8760A); // warn text
  static const Color heartOrange = Color(0xFFFF7A45); // spark / trainer accent
  static const Color sugarPurple = Color(0xFF9B8FD4); // 당류 chart
  static const Color sleepPurple = Color(0xFF6B7FE0); // 수면 chart

  // Dots / status
  static const Color redDot = Color(0xFFFF3B5C);
  static const Color statusGreen = Color(0xFF34C759);
  static const Color onlineGreen = Color(0xFF4ADE80);

  // Surfaces
  static const Color softBlue = Color(0xFFF2F9FB); // pill / accent bg
  static const Color iconTint = Color(0xFFEDF7FC); // icon chip / soft button bg
  static const Color bannerStart = Color(0xFFEDF7FC);
  static const Color bannerEnd = Color(0xFFD6EEF8);
  static const Color track = Color(0xFFF2F4F7); // progress track
  static const Color statBg = Color(0xFFF8FAFB);
  static const Color hairline = Color(0x14000000); // rgba(0,0,0,0.08)
  static const Color sheetScrim = Color(0x8008121C); // rgba(8,18,28,0.5)

  static Color primaryA(double a) => primary.withValues(alpha: a);
  static Color greenA(double a) => green.withValues(alpha: a);
  static Color orangeA(double a) => orange.withValues(alpha: a);
}

/// Shared soft-blue card shadow used by every card across all tabs so the
/// elevation reads identically everywhere. (primary #3EAFDF @ ~0.14, blur 18,
/// y+6). Apply as `boxShadow: kCardShadow` on any white content card.
const List<BoxShadow> kCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x203EAFDF),
    blurRadius: 10,
    offset: Offset(0, 3),
  ),
];

/// The On-Care mascot ("Oni") — a teal gradient disc with two eyes and a
/// smile. Used in the coaching banner, coaching sheet, chat and the FAB.
class OniAvatar extends StatelessWidget {
  const OniAvatar({super.key, this.size = 36, this.shadow = true});

  final double size;
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
          colors: <Color>[FigmaColors.primary, FigmaColors.oniEnd],
        ),
        boxShadow: shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: FigmaColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.58),
          painter: _OniFacePainter(Colors.white),
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
    // Eyes wider apart and set higher, with a bigger smile lower down so the
    // eye-to-mouth gap reads clearly (per reference smiley).
    canvas.drawCircle(Offset(7.6 * s, 8.7 * s), 1.5 * s, fill);
    canvas.drawCircle(Offset(16.4 * s, 8.7 * s), 1.5 * s, fill);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * s
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final Path smile = Path()
      ..moveTo(7.2 * s, 15 * s)
      ..quadraticBezierTo(12 * s, 19.2 * s, 16.8 * s, 15 * s);
    canvas.drawPath(smile, stroke);
  }

  @override
  bool shouldRepaint(covariant _OniFacePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The small "✦ AI 코칭 / ✦ AI 분석 …" pill badge used across the redesign.
class AiPill extends StatelessWidget {
  const AiPill(
    this.text, {
    super.key,
    this.color = FigmaColors.primary,
    this.background,
    this.fontSize = 8.5,
    this.fontWeight = FontWeight.w700,
  });

  final String text;
  final Color color;
  final Color? background;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}

/// A filled heart in the brand colour — the On-Care wordmark logo used in the
/// Home header.
class HeartLogo extends StatelessWidget {
  const HeartLogo({super.key, this.size = 20, this.color = FigmaColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.favorite, size: size, color: color);
  }
}

/// A soft round icon button (36×36, `#F2F9FB` fill, brand-blue glyph) used in
/// the tab headers, with an optional status dot.
class FigmaCircleButton extends StatelessWidget {
  const FigmaCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.showDot = false,
    this.dotColor = FigmaColors.orange,
    this.size = 36,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;
  final Color dotColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Material(
              color: FigmaColors.softBlue,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Icon(icon, size: iconSize, color: FigmaColors.primary),
                ),
              ),
            ),
          ),
          if (showDot)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The sticky title header used by the 식단 / 운동 / MY tabs: an extrabold
/// title on the left, bell + calendar circle buttons on the right.
class FigmaTabHeader extends StatelessWidget {
  const FigmaTabHeader({
    super.key,
    required this.title,
    this.onBell,
    this.onCalendar,
  });

  final String title;
  final VoidCallback? onBell;
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          FigmaCircleButton(
            icon: Icons.notifications_none_rounded,
            showDot: true,
            onTap: onBell,
          ),
          const SizedBox(width: 10),
          FigmaCircleButton(
            icon: Icons.calendar_today_outlined,
            iconSize: 16,
            onTap: onCalendar,
          ),
        ],
      ),
    );
  }
}
