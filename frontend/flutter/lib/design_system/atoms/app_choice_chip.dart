import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';

/// 하나를 고르는 둥근 사각형 칩. (#1457)
///
/// 운동 추가 시트의 운동 종류·강도 선택이 쓰던 모양을 그대로 꺼낸 것이다.
/// 개인운동 완료창의 수행 강도가 `SegmentedButton`(셋이 하나의 타원으로 이어진
/// 모양)을 쓰고 있어, 같은 3단계 강도가 화면마다 다른 UI 로 보였다. 두 자리가
/// 이 위젯 하나를 쓰면 한쪽만 다시 달라질 자리가 없다.
///
/// 색으로만 말하지 않는다 — [Semantics] 가 선택 상태를 함께 알린다.
class AppChoiceChip extends StatelessWidget {
  /// Creates a chip.
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.center = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 남는 폭을 받는 자리(한 줄에 셋을 고르게 나눌 때)에서 글자를 가운데 둔다.
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: center ? Alignment.center : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? FigmaColors.primaryA(0.10) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? FigmaColors.primary : FigmaColors.hairline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? FigmaColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
