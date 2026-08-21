import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart'
    show programExerciseMetrics;
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 프로그램 흐름의 **최종 검토** 단계 (#1028).
///
/// 이 화면이 프로그램 편집기 경로에서 회원에게 실제로 무언가를 보낼 수 있는
/// 유일한 자리다. 편집기에는 더 이상 `배정`·`PT 등록` 이 없고, 여기 올라온
/// [draft] 는 편집기가 넘긴 **스냅샷**이라 검토하는 동안 값이 바뀌지 않는다.
///
/// 화면에 그리는 값과 실제 payload 가 같은 곳에서 나온다 — 운동 지표는
/// 편집기와 같은 [programExerciseMetrics] 로 만들고, 세션 순서·이름도
/// `programAssignToJson`/`ProgramItem` 이 읽는 그 [draft] 를 그대로 훑는다.
class ProgramFinalReviewCard extends StatelessWidget {
  /// Creates the final review for [draft].
  const ProgramFinalReviewCard({
    super.key,
    required this.draft,
    required this.clientName,
    required this.registerOffset,
    required this.onRegisterOffsetChanged,
    required this.onBack,
    required this.onAssign,
    required this.onRegister,
    this.assigning = false,
    this.registering = false,
  });

  /// 전송될 구성 그대로의 스냅샷.
  final ProgramEditorState draft;

  /// 받을 회원의 표시 이름.
  final String clientName;

  /// PT 스케줄에 등록할 날(0 = 오늘 … 6).
  final int registerOffset;
  final ValueChanged<int> onRegisterOffsetChanged;

  /// 편집기로 돌아간다 — 검토하던 구성 그대로 다시 열린다.
  final VoidCallback onBack;

  /// 회원에게 프로그램을 배정한다(숙제).
  final VoidCallback onAssign;

  /// 선택한 날의 PT 세션 프로그램으로 등록한다.
  final VoidCallback onRegister;

  /// 배정이 진행 중이거나 이미 끝났다 — 버튼이 잠긴다.
  final bool assigning;

  /// 일정 등록이 진행 중이거나 이미 끝났다.
  final bool registering;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final korean = Localizations.localeOf(context).languageCode == 'ko';
    final multi = draft.sessions.length > 1;
    return SectionCard(
      key: const ValueKey<String>('program-final-review'),
      title: l.programReviewTitle,
      icon: Icons.fact_check_outlined,
      dense: true,
      trailing: ActionButton(
        key: const ValueKey<String>('program-review-back'),
        label: l.programReviewBack,
        icon: Icons.edit_outlined,
        onPressed: onBack,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.programReviewBlurb(clientName),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            draft.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (draft.goal.trim().isNotEmpty)
                _ReviewChip(label: l.programEditorGoal, value: draft.goal),
              if (draft.period.trim().isNotEmpty)
                _ReviewChip(label: l.programEditorPeriod, value: draft.period),
              if (draft.memo.trim().isNotEmpty)
                _ReviewChip(label: l.programEditorMemo, value: draft.memo),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final session in draft.sessions) ...<Widget>[
            Container(
              key: ValueKey<String>('program-review-session-${session.id}'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.all(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // 세션이 하나뿐이면 일정에도 세션 이름이 붙지 않는다
                      // (`_draftProgram`) — 화면에서도 이름을 굳이 세우지 않아
                      // 검토 내용과 전송 내용이 그대로 겹친다.
                      if (multi)
                        Expanded(
                          child: Text(
                            session.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      Text(
                        l.programReviewSessionSummary(session.exercises.length),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.subtleForeground,
                        ),
                      ),
                    ],
                  ),
                  for (final exercise in session.exercises) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _ReviewExerciseRow(
                      exercise: exercise,
                      metrics: programExerciseMetrics(
                        exercise,
                        korean: korean,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          // 등록할 날 — 편집기가 아니라 검토 단계에서 고른다. 바로 아래
          // `PT 스케줄에 등록` 이 이 값을 쓴다.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (var offset = 0; offset < 7; offset++) ...<Widget>[
                  ChoiceChip(
                    label: Text(_dayLabel(l, offset)),
                    selected: registerOffset == offset,
                    onSelected: (_) => onRegisterOffsetChanged(offset),
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.borderStrong),
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: registerOffset == offset
                          ? AppColors.primaryForeground
                          : AppColors.mutedForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 실제 전송 두 갈래. 이 앱에서 이 버튼들이 존재하는 곳은 여기뿐이다.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: AppSpacing.sm,
            overflowSpacing: AppSpacing.xs,
            children: <Widget>[
              ActionButton(
                key: const ValueKey<String>('program-editor-register'),
                label: l.coachRegisterOn(_dayLabel(l, registerOffset)),
                icon: Icons.calendar_today_outlined,
                onPressed: registering ? null : onRegister,
              ),
              ActionButton(
                key: const ValueKey<String>('program-editor-assign'),
                label: l.programEditorAssign,
                primary: true,
                onPressed: assigning ? null : onAssign,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _dayLabel(AppLocalizations l, int offset) {
  if (offset == 0) return l.labelToday;
  if (offset == 1) return l.labelTomorrow;
  final date = nowKst().add(Duration(days: offset));
  return '${date.month}/${date.day}';
}

class _ReviewExerciseRow extends StatelessWidget {
  const _ReviewExerciseRow({required this.exercise, required this.metrics});

  final ProgramExerciseDraft exercise;
  final List<String> metrics;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (metrics.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    metrics.join(' · '),
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (exercise.memo.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    exercise.memo,
                    style: const TextStyle(
                      color: AppColors.subtleForeground,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (exercise.source == 'trainer')
            Text(
              l.coachTrainerAdded,
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewChip extends StatelessWidget {
  const _ReviewChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        '$label · $value',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
