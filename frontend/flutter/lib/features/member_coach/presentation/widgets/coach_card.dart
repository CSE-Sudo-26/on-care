import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/errors/app_error.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';

/// 담당 트레이너 관계와 소통만 담는다 — 이름·전문 분야·프로필 이동·채팅.
///
/// 추천 개인운동은 여기 있지 않다. 트레이너 추천이든 AI 추천이든 회원에게는
/// "지금 무엇을 하면 되는가" 라는 한 가지 질문이라, [AiCoachingCard] 의
/// `추천 개인운동` 한 곳에 모았다(#782). 예전에는 이 카드와 AI 카드가 화면
/// 두 곳에 나뉘어 있어 둘의 관계와 우선순위를 회원이 다시 해석해야 했다.
class CoachCard extends ConsumerWidget {
  const CoachCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAsync = ref.watch(memberCoachProvider);
    final coach = coachAsync.valueOrNull;
    if (coach == null) return const SizedBox.shrink();
    // 트레이너 상세는 이제 트레이너 id 로 라우팅한다 — 한 헬스장에
    // 여러 명이 있으므로 헬스장 id 로는 한 명을 특정할 수 없다.
    final assignedTrainer = ref.watch(myTrainerProvider).valueOrNull;

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
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('assignedTrainerProfile'),
                onTap: assignedTrainer == null
                    ? null
                    : () => context.push(
                        AppRoutes.trainerDetailPath(assignedTrainer.id),
                      ),
                borderRadius: BorderRadius.circular(12),
                child: Row(
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
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          Text(
                            '${coach.name} · ${coach.specialty}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 화살표는 '누르면 간다'는 신호다. 트레이너 상세로 갈 수
                    // 없을 때(myTrainerProvider 가 아직 없거나 연결이 끊긴
                    // 경우)는 지운다 — 예전에는 화살표만 남아 눌러도 아무 일이
                    // 없었다(#786).
                    if (assignedTrainer != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: FigmaColors.textMuted,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
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

/// 운동 탭의 `AI 코칭` — 코칭 포인트와 추천 개인운동을 한 흐름으로 보여준다.
///
/// 예전에는 `AI 맞춤 조언`(텍스트)과 `AI 맞춤 운동`(카드)이 화면 위아래로 멀리
/// 떨어져 있고 그 사이에 운동 현황·트레이너 카드가 끼어 있었다. 둘은 같은
/// 기록에서 나온 같은 판단인데, 회원은 "왜 이 운동인지" 를 다시 이어 붙여야
/// 했다(#782).
///
/// 추천 개인운동은 `추가 운동` 이 아니라 **PT 와 다음 PT 사이에 스스로 하는
/// 운동**이다. 그래서 추천할 것이 없는 날은 빈 카드를 만들지 않고 코칭 포인트만
/// 남긴다 — AI 가 매번 운동을 억지로 만들어 낼 이유가 없다.
class AiCoachingCard extends ConsumerWidget {
  const AiCoachingCard({required this.coachingPoint, super.key});

  /// 이번 코칭 포인트. 운동 주간 데이터의 `aiCoachMessage` 가 그대로 들어온다.
  final String coachingPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 트레이너 추천과 AI 추천을 한 목록으로 합친다. 회원에게는 "지금 무엇을
    // 하면 되는가" 라는 한 가지 질문이고, 누가 정했는지는 각 줄의 출처가 말한다.
    final List<CoachRoutine> routines =
        ref.watch(coachRoutinesProvider).valueOrNull ?? const <CoachRoutine>[];
    final MemberCoach? coach = ref.watch(memberCoachProvider).valueOrNull;
    final String point = coachingPoint.trim();

    // 코칭 포인트도 추천도 없으면 카드 자체를 그리지 않는다. 빈 카드는 자리만
    // 차지하고 아무것도 알려 주지 않는다.
    if (point.isEmpty && routines.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const Key('aiCoachingCard'),
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
              // 큰 글자 배율에서 제목이 카드를 넘겼다(#766).
              Flexible(
                child: Text(
                  'AI 코칭',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (point.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              '이번 코칭 포인트',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FigmaColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              point,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: FigmaColors.ink,
              ),
            ),
          ],
          if (routines.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              '추천 개인운동',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FigmaColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'PT 와 다음 PT 사이에 스스로 하는 운동이에요',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            for (final (int index, CoachRoutine routine)
                in routines.indexed) ...<Widget>[
              // 여러 세션짜리 프로그램은 첫 세션 위에 프로그램 이름을 한 번
              // 얹는다 — 세션 카드가 어디에 묶이는지 보이지 않으면 그냥 낱개
              // 루틴 여러 개로 읽힌다(#709).
              if (routine.programName.isNotEmpty &&
                  (index == 0 ||
                      routines[index - 1].programName != routine.programName))
                _ProgramHeading(name: routine.programName),
              _RecommendedExerciseRow(
                routine: routine,
                sourceLabel: routineSourceLabel(routine, coach),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

/// 회원이 읽을 수 있는 추천 출처 문구.
///
/// 내부 `source` 값을 그대로 보여 주지 않는다. 회원이 알아야 할 것은 "누가
/// 확인했는가" 다 — 트레이너가 본 추천과 AI 가 혼자 낸 추천은 무게가 다르다.
///
/// 담당 트레이너가 있으면 AI 추천은 승인된 것만 내려온다(#790). 그래서 여기
/// 도착한 AI 추천에 `트레이너 확인` 을 붙이는 것이 사실이다.
String routineSourceLabel(CoachRoutine routine, MemberCoach? coach) {
  if (routine.isTrainerRecommended) return '트레이너 직접 추천';
  if (coach != null) return 'AI 추천 · ${coach.name} 확인';
  return 'AI 자동 추천';
}

class _RecommendedExerciseRow extends ConsumerStatefulWidget {
  const _RecommendedExerciseRow({
    required this.routine,
    required this.sourceLabel,
  });

  /// 회원이 읽는 출처 한 줄 — `AI 추천 · 김트레이너 확인` 처럼.
  final String sourceLabel;

  final CoachRoutine routine;

  @override
  ConsumerState<_RecommendedExerciseRow> createState() =>
      _RecommendedExerciseRowState();
}

class _RecommendedExerciseRowState
    extends ConsumerState<_RecommendedExerciseRow> {
  bool _saving = false;

  Future<void> _complete() async {
    final CoachRoutine routine = widget.routine;
    final _RoutineCompletionInput? input =
        await showDialog<_RoutineCompletionInput>(
          context: context,
          builder: (_) => _RoutineCompletionDialog(
            initialMinutes: routine.minutes > 0 ? routine.minutes : 1,
          ),
        );
    if (input == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(memberCoachRepositoryProvider)
          .completeRoutine(
            routine.id,
            minutes: input.minutes,
            intensity: input.intensity,
            memberNote: input.note,
          );
      ref.invalidate(coachRoutinesProvider);
      ref.invalidate(exerciseWeekProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('운동 기록에 반영했어요')));
      }
    } catch (error, stackTrace) {
      debugPrint('completeRoutine failed: $error\n$stackTrace');
      if (mounted) {
        if (error is NotFoundError) {
          ref.invalidate(coachRoutinesProvider);
        }
        final String message = switch (error) {
          NotFoundError() => '이 루틴은 더 이상 없어요. 목록을 새로 불러와 주세요',
          NetworkError() => '네트워크 연결을 확인하고 다시 시도해 주세요',
          _ => '완료 기록에 실패했어요.',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CoachRoutine routine = widget.routine;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      routine.isProgramSession
                          ? routine.sessionName
                          : routine.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.ink,
                      ),
                    ),
                    // 운동 구성이 오면 그것을 보여 준다 — 이름만 이어 붙인
                    // reason 보다 정확하다(세트·횟수·중량까지 온다, #709).
                    if (routine.exercises.isNotEmpty)
                      for (final CoachRoutineExercise exercise
                          in routine.exercises) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          exercise.detail.isEmpty
                              ? exercise.name
                              : '${exercise.name} · ${exercise.detail}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.foreground,
                          ),
                        ),
                      ]
                    else if (routine.reason.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        routine.reason,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                    // 누가 이 운동을 정했는지. 트레이너가 본 추천과 AI 가 혼자
                    // 낸 추천은 회원에게 무게가 다르다(#782).
                    const SizedBox(height: 4),
                    Text(
                      widget.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 오른쪽 묶음도 접힌다. 고정 폭으로 두면 큰 글자 배율에서
              // 운동 이름 쪽을 다 밀어낸 뒤에도 줄이 넘쳤다(#766).
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${routine.type} · '
                      '${routine.completedMinutes ?? routine.minutes}분',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (routine.completed)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Flexible(child: Text('수행 완료')),
                        ],
                      )
                    else
                      SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          key: Key('completeRoutine-${routine.id}'),
                          onPressed: _saving ? null : _complete,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  '수행 완료',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (routine.memberNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('내 메모: ${routine.memberNote}'),
          ],
          if (routine.trainerFeedback.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              key: Key('routineFeedback-${routine.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FigmaColors.softBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '트레이너 피드백: ${routine.trainerFeedback}',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: FigmaColors.ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineCompletionInput {
  const _RoutineCompletionInput({
    required this.minutes,
    required this.intensity,
    required this.note,
  });

  final int minutes;
  final String intensity;
  final String note;
}

class _RoutineCompletionDialog extends StatefulWidget {
  const _RoutineCompletionDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_RoutineCompletionDialog> createState() =>
      _RoutineCompletionDialogState();
}

class _RoutineCompletionDialogState extends State<_RoutineCompletionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _minutesController;
  final TextEditingController _noteController = TextEditingController();
  String _intensity = 'moderate';

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(
      text: '${widget.initialMinutes}',
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('루틴 수행 완료'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('routineCompletionMinutes'),
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '실제 수행 시간(분)'),
              validator: (String? value) {
                final int? minutes = int.tryParse(value ?? '');
                return minutes == null || minutes < 1 || minutes > 600
                    ? '1~600분 사이로 입력해 주세요'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('수행 강도')),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              key: const Key('routineCompletionIntensity'),
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'light', label: Text('가벼움')),
                ButtonSegment<String>(value: 'moderate', label: Text('보통')),
                ButtonSegment<String>(value: 'high', label: Text('높음')),
              ],
              selected: <String>{_intensity},
              onSelectionChanged: (Set<String> selected) {
                setState(() => _intensity = selected.single);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('routineCompletionNote'),
              controller: _noteController,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모(선택)',
                hintText: '힘들었던 점이나 몸 상태를 남겨 보세요',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirmRoutineCompletion'),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(
              _RoutineCompletionInput(
                minutes: int.parse(_minutesController.text),
                intensity: _intensity,
                note: _noteController.text,
              ),
            );
          },
          child: const Text('완료 기록'),
        ),
      ],
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String unreadLabel = unread > 99 ? '99+' : '$unread';

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
              // 큰 글자 배율에서 라벨이 버튼을 넘겼다. 안 읽은 개수 배지는
              // 접지 않는다 — 몇 건인지가 이 버튼을 누를 이유다(#766).
              const Flexible(
                child: Text(
                  '트레이너와 채팅',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.primary,
                  ),
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
                    unreadLabel,
                    style: const TextStyle(
                      fontSize: 12,
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

/// 여러 세션이 묶인 프로그램의 이름표. (#709)
class _ProgramHeading extends StatelessWidget {
  const _ProgramHeading({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.list_alt_outlined,
            size: 15,
            color: FigmaColors.primary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: FigmaColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
