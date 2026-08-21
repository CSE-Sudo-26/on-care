import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

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
  static const Color heartOrange = Color(
    0xFFFF953C,
  ); // spark accent(주의 오렌지로 통일)
  static const Color sugarPurple = Color(0xFF9B8FD4); // 당류 chart

  // 식단 기간 그래프의 탄단지 3색 — **브랜드 색 하나의 농담**이다. (#953)
  //
  // 처음에는 남색(indigo) 램프였는데, `오늘` 뷰가 칼로리 링도 탄단지 진행 바도
  // 모두 [primary] 하나로 그리는 탓에 토글로 두 뷰를 오갈 때 색이 튀었다.
  // 셋은 서로 다른 지표가 아니라 **한 칼로리를 나눈 것**이라, 색상환을 바꾸는
  // 것보다 농담으로 가르는 편이 뜻에도 맞는다.
  //
  // 값은 [primary] 를 흰 배경 위에 100% / 65% / 35% 로 얹은 결과다. 알파 대신
  // 불투명 값으로 박아 두는 이유는 막대가 목표선 위에 겹쳐 그려지기 때문이다 —
  // 반투명이면 선이 비쳐 층 경계가 흐려진다.
  //
  // 운동 탭 `운동 현황` 의 3색(#3EAFDF · #1B6FA8 · #D4EEF8)은 **서로 다른 세
  // 색**이고 이쪽은 **한 색의 농담**이라, 나란히 놓아도 두 그래프가 같은 뜻으로
  // 읽히지 않는다.
  static const Color macroCarbs = Color(0xFF3EAFDF); // 탄수화물 — 브랜드 100%
  static const Color macroProtein = Color(0xFF82CBEA); // 단백질 — 브랜드 65%
  static const Color macroFat = Color(0xFFBBE3F4); // 지방 — 브랜드 35%
  static const Color sleepPurple = Color(0xFF6B7FE0); // 수면 chart

  // Dots / status
  static const Color redDot = Color(0xFFFF3B5C);
  static const Color dangerRed = Color(0xFFF04438); // 초과/경고 강조(나트륨 초과 등)
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

  // --- 상태 시맨틱 별칭 (#995) ---
  //
  // 사용자앱 화면은 대부분 [FigmaColors] 를 읽으므로, 두 앱 공통 시맨틱 토큰을
  // 여기서도 같은 이름으로 꺼내 쓴다. 값의 출처는 [AppColors] 한 곳이다.
  static const Color statusNormal = AppColors.statusNormal;
  static const Color statusWithinGoal = AppColors.statusWithinGoal;
  static const Color statusCaution = AppColors.statusCaution;
  static const Color statusCautionFill = AppColors.statusCautionFill;
  static const Color statusDanger = AppColors.statusDanger;
  static const Color statusOver = AppColors.statusOver;
  static const Color dietChart = AppColors.dietChart;
  static const Color exerciseChart = AppColors.exerciseChart;
  static const Color chartGoalLine = AppColors.chartGoalLine;

  static Color primaryA(double a) => primary.withValues(alpha: a);
  static Color greenA(double a) => green.withValues(alpha: a);
  static Color orangeA(double a) => orange.withValues(alpha: a);
}

/// Shared neutral grey card shadow used by every card across all tabs so the
/// elevation reads identically everywhere. (검정 @ 10% (0x1A), blur 14, y+4).
/// Apply as `boxShadow: kCardShadow` on any white content card.
///
/// 예전에는 브랜드 블루(#3EAFDF) 그림자였는데, 홈 개편에서 회색으로 바꾸면서
/// 나머지 탭도 같은 값으로 맞췄다.
const List<BoxShadow> kCardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x1A000000), blurRadius: 14, offset: Offset(0, 4)),
];

/// Shared "/(목표|제한치)(단위)" suffix style, e.g. the "/275g" after a macro
/// value. Standardized to the home 식단 영양 카드 탄단지 look — small, faint —
/// so every "(현재)/(목표)(단위)" reads consistently across the app.
const TextStyle kGoalSuffixStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.mutedForeground,
);

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
  const HeartLogo({
    super.key,
    this.size = 20,
    this.color = FigmaColors.primary,
  });

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
    this.enabled = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;
  final Color dotColor;
  final double size;
  final double iconSize;

  /// 아이콘 하나뿐인 버튼이 무엇을 하는지. 부르는 쪽이 바깥에서 `Semantics`
  /// 로 이름을 붙였으면 비워 둔다 — 같은 말을 두 번 읽게 된다(#972).
  final String? tooltip;

  /// 지금 쓸 수 있는 버튼인지. false 면 흐리게 그린다.
  ///
  /// [onTap] 과 따로 두는 이유: 쓸 수 없다는 것과 눌러도 소용없다는 것은 다르다.
  /// 왜 쓸 수 없는지 알려 주려면 흐린 채로도 탭을 받아야 한다. 예전에는 이 구분이
  /// 없어서, 담당 트레이너가 없을 때 채팅 버튼이 멀쩡한 모습으로 죽어 있었다(#786).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // `onTap` 이 아예 없으면 그것도 쓸 수 없는 상태다.
    final bool usable = enabled && onTap != null;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Material(
              color: usable ? FigmaColors.softBlue : FigmaColors.track,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                // 아이콘 하나뿐인 버튼이라 무엇을 하는지 말할 데가 툴팁뿐이다.
                // 부르는 쪽이 밖에서 `Semantics` 로 이름을 붙였으면 여기서는
                // 아무 말도 하지 않는다 — 같은 말을 두 번 읽게 된다(#972).
                child: Tooltip(
                  message: tooltip ?? '',
                  excludeFromSemantics: tooltip == null,
                  child: Center(
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: usable
                          ? FigmaColors.primary
                          : FigmaColors.textFaint,
                    ),
                  ),
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

/// The shared main-tab header: an optional brand icon and title on the left,
/// with fixed tab actions on the right.
class FigmaTabHeader extends StatelessWidget {
  const FigmaTabHeader({
    super.key,
    required this.title,
    required this.trailingAction,
    this.leading,
    this.onBell,
    this.onCalendar,
    this.bellHasUnread = false,
  });

  final String title;
  final Widget trailingAction;
  final Widget? leading;
  final VoidCallback? onBell;
  final VoidCallback? onCalendar;

  /// 벨에 미읽음 점을 띄울지. 예전에는 항상 켜져 있어서 읽을 것이 없어도 점이
  /// 남았다 — 화면이 서버 상태를 받아 넘긴다(디자인 시스템은 알림을 모른다).
  final bool bellHasUnread;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 6)],
          Expanded(
            // 말줄임이 아니라 축소다 (#1004). 서비스 이름이 `On - Ca…` 가 되면
            // 헤더가 무엇을 가리키는지 사라진다 — 글씨를 키운 뒤로 좁은 폰에서
            // 실제로 그렇게 됐다.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          FigmaCircleButton(
            icon: Icons.notifications_none_rounded,
            tooltip: l.pageNotificationTitle,
            showDot: bellHasUnread,
            onTap: onBell,
          ),
          const SizedBox(width: 10),
          FigmaCircleButton(
            icon: Icons.calendar_today_outlined,
            tooltip: l.a11yOpenCalendar,
            iconSize: 16,
            onTap: onCalendar,
          ),
          const SizedBox(width: 10),
          trailingAction,
        ],
      ),
    );
  }
}
