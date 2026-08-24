import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/errors/app_error.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';

/// 트레이너가 보낸 담당 요청 카드. (#919)
///
/// 담당 트레이너 카드 **바로 위**에 둔다. 둘은 같은 질문의 앞뒤이기 때문이다 —
/// "내 담당은 누구인가", 그리고 "담당이 되겠다는 사람이 있다".
///
/// 카드가 수락 버튼 옆에 **무엇이 열리는지**를 함께 적는 것은 의도다. 담당
/// 관계는 내 식단·운동 기록을 그 사람에게 여는 일이라, 무엇에 동의하는지 모르고
/// 누르는 버튼이 되어서는 안 된다.
///
/// 받은 요청이 없으면 아무것도 그리지 않는다 — 늘 자리를 차지하는 빈 카드는
/// 화면만 길게 만든다.
class CoachInviteCard extends ConsumerStatefulWidget {
  const CoachInviteCard({super.key});

  @override
  ConsumerState<CoachInviteCard> createState() => _CoachInviteCardState();
}

class _CoachInviteCardState extends ConsumerState<CoachInviteCard> {
  bool _busy = false;

  /// 담당 연결 전에 무엇이 넘어가는지 알리고 동의를 받는다. (#1022)
  ///
  /// 수락하는 순간 트레이너가 회원의 식단·운동·신체 정보를 읽는다. 안내로
  /// 지나가지 않고 동의를 받아야, 회원이 무엇에 동의했는지 나중에도 말할 수
  /// 있다. 서버도 동의 없는 수락은 400 으로 막는다.
  Future<bool> _confirmConsent(CoachInvite invite) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool? agreed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        key: const Key('coachInviteConsentDialog'),
        title: Text(l.coachInviteConsentTitle),
        content: Text(l.coachInviteConsentBody(invite.trainerName)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            key: const Key('coachInviteConsentAgree'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.coachInviteConsentAgree),
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  Future<void> _decide(CoachInvite invite, {required bool accept}) async {
    if (_busy) return;
    final AppLocalizations l = AppLocalizations.of(context);
    // 동의는 수락에만 필요하다 — 거절은 아무것도 열지 않는다.
    if (accept && !await _confirmConsent(invite)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final repository = ref.read(memberCoachRepositoryProvider);
      if (accept) {
        await repository.acceptInvite(invite.id, dataSharingConsent: true);
      } else {
        await repository.rejectInvite(invite.id);
      }
      // 수락은 담당을 만든다 — 코치 카드·루틴·채팅이 모두 그 관계 위에 있으므로
      // 함께 다시 읽는다. 거절은 목록만 바뀐다.
      ref.invalidate(coachInvitesProvider);
      if (accept) {
        ref
          ..invalidate(memberCoachProvider)
          ..invalidate(coachRoutinesProvider)
          ..invalidate(coachSessionsProvider);
      }
      if (!mounted) return;
      showAppToastVia(
        messenger,
        accept
            ? l.coachInviteAccepted(invite.trainerName)
            : l.coachInviteRejected,
        kind: AppToastKind.success,
      );
    } on AppError {
      if (!mounted) return;
      showAppToastVia(messenger, l.coachInviteFailed, kind: AppToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final invites =
        ref.watch(coachInvitesProvider).valueOrNull ?? const <CoachInvite>[];
    if (invites.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        children: <Widget>[
          for (final CoachInvite invite in invites)
            Container(
              key: ValueKey<String>('coach-invite-${invite.id}'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: kCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l.coachInviteTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.coachInviteFrom(invite.trainerName),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: FigmaColors.ink,
                    ),
                  ),
                  if (invite.gymName case final String gym when gym.isNotEmpty)
                    Text(
                      l.coachInviteGym(gym),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  if (invite.message case final String message
                      when message.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: FigmaColors.ink,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 무엇에 동의하는지 버튼 위에 적는다.
                  Text(
                    l.coachInviteExplain,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          key: ValueKey<String>(
                            'coach-invite-reject-${invite.id}',
                          ),
                          onPressed: _busy
                              ? null
                              : () => _decide(invite, accept: false),
                          child: Text(l.coachInviteReject),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: ValueKey<String>(
                            'coach-invite-accept-${invite.id}',
                          ),
                          onPressed: _busy
                              ? null
                              : () => _decide(invite, accept: true),
                          child: Text(l.coachInviteAccept),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
