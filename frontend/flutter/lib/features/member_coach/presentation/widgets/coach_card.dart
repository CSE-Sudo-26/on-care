import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';

/// "담당 코치" card for the 운동 기록 sub-tab: the assigned trainer, the
/// routines they've sent, and an entry point to the chat thread. Renders
/// nothing when the member has no coach (keeps the tab clean).
class CoachCard extends ConsumerWidget {
  const CoachCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAsync = ref.watch(memberCoachProvider);
    final coach = coachAsync.valueOrNull;
    if (coach == null) return const SizedBox.shrink();

    final routines = ref.watch(coachRoutinesProvider).valueOrNull ??
        const <CoachRoutine>[];
    final unread = ref.watch(coachUnreadProvider).valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FigmaColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: FigmaColors.iconTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: FigmaColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '담당 코치',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.textMuted,
                        ),
                      ),
                      Text(
                        '${coach.name} · ${coach.specialty}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '받은 루틴',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: FigmaColors.textSub,
              ),
            ),
            const SizedBox(height: 8),
            if (routines.isEmpty)
              const Text(
                '아직 받은 루틴이 없어요',
                style: TextStyle(fontSize: 12, color: FigmaColors.textMuted),
              )
            else
              for (final r in routines) ...<Widget>[
                _RoutineRow(routine: r),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 6),
            _ChatButton(
              coachName: coach.name,
              unread: unread,
              onTap: () => showCoachChatSheet(context, coachName: coach.name),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine});

  final CoachRoutine routine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  routine.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.ink,
                  ),
                ),
                if (routine.reason.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    routine.reason,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FigmaColors.textBody,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${routine.type} · ${routine.minutes}분',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FigmaColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({
    required this.coachName,
    required this.unread,
    required this.onTap,
  });

  final String coachName;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FigmaColors.softBlue,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: FigmaColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                '코치와 대화하기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.primary,
                ),
              ),
              if (unread > 0) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: const BoxDecoration(
                    color: FigmaColors.redDot,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
