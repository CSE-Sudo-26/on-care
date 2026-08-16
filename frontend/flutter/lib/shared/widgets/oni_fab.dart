import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';

/// The floating "Oni" assistant button shown on every main tab. Taps open the
/// coaching sheet. A red badge shows the number of pending suggestions.
/// Mirrors the Figma FAB.
///
/// [badgeCount] 기본값은 0 이다. 예전에는 2 로 두고 부르는 쪽이 값을 넘기지 않아,
/// 제안 수와 무관하게 늘 '2' 가 떠 있었다 — 다 읽어도 사라지지 않았다(#788).
/// 셀 수 없을 때는 배지를 아예 그리지 않는 편이 상수보다 정직하다.
class OniFab extends StatelessWidget {
  const OniFab({super.key, required this.onTap, this.badgeCount = 0});

  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: FigmaColors.primary.withValues(alpha: 0.55),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const OniAvatar(size: 52, shadow: false),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FigmaColors.redDot,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
