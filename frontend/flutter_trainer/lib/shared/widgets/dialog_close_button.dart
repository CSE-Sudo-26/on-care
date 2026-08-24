import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';

/// 가운데 모달 카드 안쪽, 오른쪽 위 구석에 두는 닫기(x) 버튼.
///
/// 카드 밖으로 걸치면 잘리기 쉽다 — 모서리를 벗어난 만큼 다른 요소에
/// 가려지거나 탭이 닿지 않는다. 항상 카드 안쪽에 둔다.
class DialogCloseButton extends StatelessWidget {
  const DialogCloseButton({required this.onTap, this.tooltip, super.key});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // 배경 없이 X 아이콘만 둔다 — 흰 원(그림자 포함)이 늘 떠 있으면 카드
    // 구석에서 무겁게 보인다. 탭 파문은 `Material` 이 투명해도 그려진다.
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        key: const ValueKey<String>('dialog-close'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close, size: 18, color: AppColors.subtleForeground),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
