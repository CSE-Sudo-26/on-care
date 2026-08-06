import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';

/// 모든 메인 탭 헤더에서 동일한 담당 트레이너 채팅으로 진입하는 버튼이다.
class TrainerChatHeaderButton extends ConsumerWidget {
  const TrainerChatHeaderButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coach = ref.watch(memberCoachProvider).valueOrNull;
    final int unread = ref.watch(coachUnreadProvider).valueOrNull ?? 0;

    return Semantics(
      button: true,
      label: '트레이너와 채팅',
      child: FigmaCircleButton(
        key: const Key('trainerChatHeaderButton'),
        icon: Icons.chat_bubble_outline_rounded,
        showDot: unread > 0,
        dotColor: FigmaColors.redDot,
        onTap: coach == null
            ? null
            : () => openTrainerChatPage(context, trainerName: coach.name),
      ),
    );
  }
}
