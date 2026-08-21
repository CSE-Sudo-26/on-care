import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';

/// `[아이콘] 제목` 한 줄 — 식단 `영양 요약` · 운동 `운동 현황` 의 제목이다.
///
/// 트레이너웹 고객 탭의 같은 두 섹션이 이미 아이콘을 달고 있다. 회원 앱만
/// 글자만 있으면, 두 화면이 같은 것을 말하는지 한눈에 붙지 않는다. 아이콘은
/// 같은 모양을 쓰되 색은 이 앱의 메인 색이다. (#1058)
class SectionTitle extends StatelessWidget {
  /// Creates the title row.
  const SectionTitle({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: FigmaColors.primary),
        const SizedBox(width: 6),
        // 좁은 화면·큰 글자 배율에서 제목이 기간 토글을 밀어내면 안 된다.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
