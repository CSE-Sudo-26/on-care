import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';

/// AI 가 건네는 한 문단짜리 조언 카드. (#1021)
///
/// 식단 탭이 쓰던 그림을 그대로 꺼내 둔 것이다. 운동 탭도 같은 자리에서 같은
/// 말을 하게 됐는데, 두 탭이 조금씩 다른 카드를 쓰면 회원은 "이 카드가 그
/// 카드인가" 를 매번 다시 판단해야 한다.
///
/// 문구가 비면 아무것도 그리지 않는다 — 빈 카드는 자리만 차지하고 아무것도
/// 알려 주지 않는다.
class AiAdviceCard extends StatelessWidget {
  const AiAdviceCard({
    super.key,
    required this.title,
    required this.message,
  });

  /// 카드 머리 — `AI 맞춤 조언` 처럼 무슨 말인지 알려 주는 한 줄.
  final String title;

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FigmaColors.softBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FigmaColors.primaryA(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const OniAvatar(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
