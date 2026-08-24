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
    final button = Material(
      color: AppColors.card,
      shape: const CircleBorder(),
      elevation: 1,
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
