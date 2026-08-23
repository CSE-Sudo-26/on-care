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
import 'package:oncare/gen/l10n/app_localizations.dart';

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
    final AppLocalizations l = AppLocalizations.of(context);
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
                          Text(
                            l.coachAssignedTrainer,
                            style: const TextStyle(
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
  const AiCoachingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 트레이너 추천과 AI 추천을 한 목록으로 합친다. 회원에게는 "지금 무엇을
    // 하면 되는가" 라는 한 가지 질문이고, 누가 정했는지는 각 줄의 출처가 말한다.
    final List<CoachRoutine> routines =
        ref.watch(coachRoutinesProvider).valueOrNull ?? const <CoachRoutine>[];
    final MemberCoach? coach = ref.watch(memberCoachProvider).valueOrNull;

    // 추천이 없으면 카드 자체를 그리지 않는다. 빈 카드는 자리만 차지하고
    // 아무것도 알려 주지 않는다.
    //
    // 예전에는 이 카드가 `이번 코칭 포인트` 도 함께 말했다. 지금은 화면 위쪽의
    // AI 맞춤 조언 카드가 그 말을 하므로 여기서는 뺐다 — 같은 말이 한 화면에
    // 두 번 있으면 안 된다. (#1021)
    if (routines.isEmpty) return const SizedBox.shrink();

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
          Row(
            children: <Widget>[
              // 카드가 말하는 것은 `AI 코칭` 이 아니라 **추천 개인운동**이다
              // (#1130). 제목이 곧 내용이라 아이콘도 운동 쪽으로 바꿨다.
              const Icon(
                Icons.directions_run_rounded,
                size: 18,
                color: FigmaColors.primary,
              ),
              const SizedBox(width: 6),
              // 큰 글자 배율에서 제목이 카드를 넘겼다(#766).
              Flexible(
                child: Text(
                  l.coachRoutineTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (routines.isNotEmpty) ...<Widget>[
            // 카드 제목이 이미 `추천 개인운동` 이라 안에 같은 말을 또 두지
            // 않는다. `PT 와 다음 PT 사이…` 안내도 뺐다 (#1130).
            const SizedBox(height: 12),
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
                sourceLabel: routineSourceLabel(l, routine, coach),
                // 담당이 배정한 것을 회원이 조용히 없애면 다음 상담에서 둘이
                // 서로 다른 기록을 본다. 담당이 없을 때만 스스로 물린다. (#1020)
                cancellable: coach == null,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

/// 추천 운동을 했는지 표시하는 체크 박스. (#1021)
///
/// 체크한 것을 다시 누르면 **묻고 나서** 되돌린다 (#1131). 수행은 기록으로 남아
/// 주간 시간·칼로리에 더해지고 트레이너에게도 보이므로, 조용히 지워지면 안 되지만
/// 잘못 누른 체크를 풀 방법이 아예 없어도 안 된다.
class _RoutineCheckbox extends StatelessWidget {
  const _RoutineCheckbox({
    super.key,
    required this.done,
    required this.saving,
    required this.onCheck,
  });

  final bool done;
  final bool saving;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (saving) {
      return const Padding(
        padding: EdgeInsets.all(9),
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Semantics(
      checked: done,
      label: l.coachRoutineDone,
      child: Checkbox(
        value: done,
        onChanged: (bool? _) => onCheck(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        activeColor: FigmaColors.primary,
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
String routineSourceLabel(
  AppLocalizations l,
  CoachRoutine routine,
  MemberCoach? coach,
) {
  if (routine.isTrainerRecommended) return l.coachRoutineByTrainer;
  if (coach != null) return l.coachRoutineAiChecked(coach.name);
  return l.coachRoutineAiAuto;
}

class _RecommendedExerciseRow extends ConsumerStatefulWidget {
  const _RecommendedExerciseRow({
    required this.routine,
    required this.sourceLabel,
    required this.cancellable,
  });

  /// 회원이 읽는 출처 한 줄 — `AI 추천 · 김트레이너 확인` 처럼.
  final String sourceLabel;

  final CoachRoutine routine;

  /// 회원이 스스로 물릴 수 있는가 — 담당 트레이너가 없을 때만 참이다. (#1020)
  final bool cancellable;

  @override
  ConsumerState<_RecommendedExerciseRow> createState() =>
      _RecommendedExerciseRowState();
}

class _RecommendedExerciseRowState
    extends ConsumerState<_RecommendedExerciseRow> {
  bool _saving = false;

  /// 개인 운동 취소. 담당 트레이너가 없을 때만 화면에 나타난다 — 담당이 있으면
  /// 취소는 트레이너의 일이라 서버도 403 으로 막는다. (#1020)
  Future<void> _cancel() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final CoachRoutine routine = widget.routine;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(l.coachRoutineCancelConfirm(routine.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            key: const Key('confirmRoutineCancel'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.coachRoutineCancel),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(memberCoachRepositoryProvider).deleteRoutine(routine.id);
      ref.invalidate(coachRoutinesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.coachRoutineCancelled)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.coachRoutineCancelFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 체크를 되돌린다 — 묻고 나서 (#1131).
  ///
  /// 완료는 기록으로 남아 주간 시간·칼로리에 더해지고 트레이너에게도 보인다.
  /// 잘못 누른 체크를 풀 방법이 없으면 하지 않은 운동이 그 숫자에 영원히 남아,
  /// 회원과 트레이너가 서로 다른 기록을 보게 된다.
  Future<void> _undoComplete() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final CoachRoutine routine = widget.routine;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(l.coachRoutineUndoConfirm(routine.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            key: const Key('confirmRoutineUndo'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.coachRoutineUndo),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(memberCoachRepositoryProvider)
          .uncompleteRoutine(routine.id);
      ref.invalidate(coachRoutinesProvider);
      ref.invalidate(exerciseWeekProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.coachRoutineUndone)));
      }
    } on Object catch (error, stackTrace) {
      debugPrint('uncompleteRoutine failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.coachRoutineUndoFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _complete() async {
    final AppLocalizations l = AppLocalizations.of(context);
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
        ).showSnackBar(SnackBar(content: Text(l.coachRoutineLogged)));
      }
    } catch (error, stackTrace) {
      debugPrint('completeRoutine failed: $error\n$stackTrace');
      if (mounted) {
        if (error is NotFoundError) {
          ref.invalidate(coachRoutinesProvider);
        }
        final String message = switch (error) {
          NotFoundError() => l.coachRoutineGone,
          NetworkError() => l.coachRoutineNetworkError,
          _ => l.coachRoutineLogFailed,
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
    final AppLocalizations l = AppLocalizations.of(context);
    final CoachRoutine routine = widget.routine;
    // 이미 한 운동은 글자를 한 단계 낮춘다 (#1196). 체크 박스 하나만으로는
    // 여러 줄짜리 목록에서 어디까지 했는지 한눈에 갈리지 않는다 — 남은 줄이
    // 검정으로 남아 있어야 다음에 할 것이 먼저 읽힌다.
    final Color titleColor = routine.completed
        ? FigmaColors.textSub
        : FigmaColors.ink;
    final Color detailColor = routine.completed
        ? AppColors.mutedForeground
        : AppColors.foreground;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 했는지 안 했는지는 체크 박스로 말한다 (#1021). 예전에는 오른쪽
              // 아래에 `수행 완료` 버튼이 있었는데, 시간·유형 아래에 붙어 있어
              // 무엇에 대한 버튼인지 한눈에 붙지 않았다. 체크 박스를 줄 맨
              // 앞에 두면 "이 운동을 했다" 가 그 줄에서 바로 읽힌다.
              _RoutineCheckbox(
                key: Key('completeRoutine-${routine.id}'),
                done: routine.completed,
                saving: _saving,
                onCheck: routine.completed ? _undoComplete : _complete,
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      routine.isProgramSession
                          ? routine.sessionName
                          : routine.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
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
                          style: TextStyle(
                            fontSize: 12.5,
                            color: detailColor,
                          ),
                        ),
                      ]
                    else if (routine.reason.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        routine.reason,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: detailColor,
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
              // 오른쪽 묶음은 **제 몫을 다 차지한다** (#1153). `Flexible` 은
              // 내용 크기로 줄어들어, 남은 자리가 그 오른쪽에 빈 칸으로 남았고
              // 값이 카드 가운데에서 끝난 것처럼 보였다. 폭을 받아 두고 안에서
              // 오른쪽 정렬하면 값이 카드 끝에 붙는다. 글자 배율이 커지면
              // 아래 FittedBox 가 값부터 줄인다(#766).
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    // 카드 오른쪽 끝에 한 줄로 붙인다 (#1130). 두 줄로
                    // 접히면 첫 줄이 카드 가운데에서 끝나 어디에 걸린 값인지
                    // 애매해진다.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${routine.type} · '
                        '${l.unitMinutesValue(routine.completedMinutes ?? routine.minutes)}',
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                    // 아직 하지 않은 것만 물릴 수 있다 — 이미 한 운동을 목록에서
                    // 지우면 기록과 화면이 갈린다.
                    if (widget.cancellable && !routine.completed)
                      TextButton(
                        key: Key('cancelRoutine-${routine.id}'),
                        onPressed: _saving ? null : _cancel,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.mutedForeground,
                        ),
                        child: Text(
                          l.coachRoutineCancel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
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
            Text(l.coachRoutineMyNote(routine.memberNote)),
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
                l.coachRoutineTrainerFeedback(routine.trainerFeedback),
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
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.coachRoutineCompleteTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('routineCompletionMinutes'),
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.coachRoutineMinutesLabel,
              ),
              validator: (String? value) {
                final int? minutes = int.tryParse(value ?? '');
                return minutes == null || minutes < 1 || minutes > 600
                    ? l.coachRoutineMinutesError
                    : null;
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l.coachRoutineIntensity),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              key: const Key('routineCompletionIntensity'),
              // value 는 서버로 나가는 계약이라 그대로 두고, 라벨만 로케일을
              // 따른다(#847).
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'light',
                  label: Text(l.coachIntensityLight),
                ),
                ButtonSegment<String>(
                  value: 'moderate',
                  label: Text(l.coachIntensityModerate),
                ),
                ButtonSegment<String>(
                  value: 'high',
                  label: Text(l.coachIntensityHigh),
                ),
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
              decoration: InputDecoration(
                labelText: l.coachRoutineNoteLabel,
                hintText: l.coachRoutineNoteHint,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
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
          child: Text(l.coachRoutineSubmit),
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
    final AppLocalizations l = AppLocalizations.of(context);
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
              Flexible(
                // 줄임표 대신 축소다 — `Chat with train…` 이 되면 버튼이 무슨
                // 버튼인지 사라진다. (#1004)
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l.coachChatWithTrainer,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
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
