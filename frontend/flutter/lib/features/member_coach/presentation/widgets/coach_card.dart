import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';

/// 담당 트레이너 정보와 트레이너가 직접 추천한 개인운동을 표시한다.
class CoachCard extends ConsumerWidget {
  const CoachCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAsync = ref.watch(memberCoachProvider);
    final coach = coachAsync.valueOrNull;
    if (coach == null) return const SizedBox.shrink();

    final List<CoachRoutine> trainerRoutines =
        (ref.watch(coachRoutinesProvider).valueOrNull ?? const <CoachRoutine>[])
            .where((CoachRoutine routine) => routine.isTrainerRecommended)
            .toList();
    final unread = ref.watch(coachUnreadProvider).valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kCardShadow,
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
                        '담당 트레이너',
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
              '트레이너 추천 추가 개인운동',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FigmaColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (trainerRoutines.isEmpty)
              const Text(
                '아직 트레이너가 추천한 개인운동이 없어요',
                style: TextStyle(fontSize: 12, color: FigmaColors.textMuted),
              )
            else
              for (final CoachRoutine routine in trainerRoutines) ...<Widget>[
                _RecommendedExerciseRow(routine: routine),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 6),
            _ChatButton(
              unread: unread,
              onTap: () =>
                  openTrainerChatPage(context, trainerName: coach.name),
            ),
          ],
        ),
      ),
    );
  }
}

/// 건강 기록과 PT 피드백을 바탕으로 생성된 AI 추천 개인운동만 표시한다.
class AiRecommendedExerciseCard extends ConsumerWidget {
  const AiRecommendedExerciseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CoachRoutine> aiRoutines =
        (ref.watch(coachRoutinesProvider).valueOrNull ?? const <CoachRoutine>[])
            .where((CoachRoutine routine) => routine.isAiRecommended)
            .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: FigmaColors.primary),
              SizedBox(width: 6),
              Text(
                'AI 맞춤 운동',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '나의 건강 기록과 트레이너 PT 피드백을 바탕으로 AI가 추천한 개인운동이에요',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (aiRoutines.isEmpty)
            const Text(
              '현재 추천할 수 있는 AI 맞춤 운동이 없어요',
              style: TextStyle(fontSize: 12, color: FigmaColors.textMuted),
            )
          else
            for (final CoachRoutine routine in aiRoutines) ...<Widget>[
              _RecommendedExerciseRow(routine: routine),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RecommendedExerciseRow extends StatelessWidget {
  const _RecommendedExerciseRow({required this.routine});

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
  const _ChatButton({required this.unread, required this.onTap});

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
                '트레이너와 채팅',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.primary,
                ),
              ),
              if (unread > 0) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
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
