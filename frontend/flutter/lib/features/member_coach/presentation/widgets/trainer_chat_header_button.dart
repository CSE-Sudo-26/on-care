import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';

/// 모든 메인 탭 헤더에서 동일한 담당 트레이너 채팅으로 진입하는 버튼이다.
///
/// 담당 트레이너가 아직 없거나 조회 중이면 흐리게 그리고, 눌렀을 때는 왜 지금은
/// 쓸 수 없는지 한 줄로 알린다. 예전에는 이 상태에서 `onTap: null` 만 넘겨서
/// 모양은 그대로인 채 아무 반응도 없었다 — 고장 난 버튼으로 읽혔다(#786).
class TrainerChatHeaderButton extends ConsumerWidget {
  const TrainerChatHeaderButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MemberCoach?> coachAsync = ref.watch(memberCoachProvider);
    final MemberCoach? coach = coachAsync.valueOrNull;
    final int unread = ref.watch(coachUnreadProvider).valueOrNull ?? 0;
    final bool ready = coach != null;

    // 아직 받아 오는 중인지, 받아 봤더니 없는지는 다른 사정이다. 안내 문구도 달라야
    // 한다 — 로딩 중에 "트레이너가 없다" 고 말하면 거짓이 된다.
    final String unavailableReason = coachAsync.isLoading
        ? '담당 트레이너를 불러오는 중이에요'
        : '담당 트레이너가 아직 없어요. 운동 탭에서 헬스장·트레이너를 연결해 보세요';

    return Semantics(
      button: true,
      enabled: ready,
      label: '트레이너와 채팅',
      child: FigmaCircleButton(
        key: const Key('trainerChatHeaderButton'),
        icon: Icons.chat_bubble_outline_rounded,
        showDot: unread > 0,
        dotColor: FigmaColors.redDot,
        enabled: ready,
        onTap: ready
            ? () => openTrainerChatPage(context, trainerName: coach.name)
            : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(unavailableReason)),
              ),
      ),
    );
  }
}
