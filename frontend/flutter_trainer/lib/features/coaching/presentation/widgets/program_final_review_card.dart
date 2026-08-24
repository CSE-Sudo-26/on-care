import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart'
    show programExerciseMetrics;
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// `고객에게 배정` 을 누르기 전 한 번 더 확인한다(#1029) — 이 버튼 하나가
/// 배정과 PT 일정 등록을 함께 하므로, 무엇이 나가는지 미리 말해야 한다.
/// `showRoutineSuggestionConfirmDialog` 와 같은 모양을 쓴다.
Future<bool?> showProgramAssignConfirmDialog(
  BuildContext context, {
  required String clientName,
  required DateTime registerDate,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final AppLocalizations l = AppLocalizations.of(dialogContext);
      return AlertDialog(
        key: const ValueKey<String>('program-assign-confirm'),
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
        title: Text(
          l.programAssignConfirmTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 360,
          child: Text(
            l.programAssignConfirmBody(clientName, ymd(registerDate)),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
              height: 1.4,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('program-assign-confirm-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('program-assign-confirm-submit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.programEditorAssign),
          ),
        ],
      );
    },
  );
}

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
    required this.registerDate,
    required this.onRegisterDateChanged,
    required this.onBack,
    required this.onAssign,
    this.assigning = false,
  });

  /// 전송될 구성 그대로의 스냅샷.
  final ProgramEditorState draft;

  /// 받을 회원의 표시 이름.
  final String clientName;

  /// PT 스케줄에 등록할 날. 기본값은 오늘.
  final DateTime registerDate;
  final ValueChanged<DateTime> onRegisterDateChanged;

  /// 편집기로 돌아간다 — 검토하던 구성 그대로 다시 열린다.
  final VoidCallback onBack;

  /// 확인 다이얼로그를 지난 뒤 실행한다 — 회원에게 프로그램을 배정하고
  /// (숙제), 이어서 [registerDate] 로 PT 세션 프로그램도 등록한다(#1029).
  /// 두 API 는 여전히 따로다 — 호출부(`_CoachingPageState`)가 순서대로
  /// 부르되, 이 화면에는 CTA 하나로만 보인다.
  final VoidCallback onAssign;

  /// 배정이 진행 중이거나 이미 끝났다 — 버튼이 잠긴다.
  final bool assigning;

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
          // 등록할 날 — 편집기가 아니라 검토 단계에서 고른다. 아래 `고객에게
          // 배정` 이 배정과 함께 이 날짜로 PT 일정도 등록한다(#1029) — 예전
          // `PT 스케줄에 등록` 버튼은 없앴다. 기본값은 오늘.
          Align(
            alignment: Alignment.centerLeft,
            child: ActionButton(
              key: const ValueKey<String>('program-register-date'),
              label: ymd(registerDate),
              icon: Icons.calendar_month_outlined,
              onPressed: assigning ? null : () => _pickDate(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 실제 전송. 이 앱에서 이 버튼이 존재하는 곳은 여기뿐이다. 누르면
          // 곧바로 나가지 않고 확인창을 한 번 거친다(#1029) — 배정과 PT
          // 등록이 한 버튼에 묶인 만큼, 무엇이 함께 나가는지 미리 말해야
          // 한다.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: AppSpacing.sm,
            overflowSpacing: AppSpacing.xs,
            children: <Widget>[
              ActionButton(
                key: const ValueKey<String>('program-editor-assign'),
                label: l.programEditorAssign,
                primary: true,
                onPressed: assigning
                    ? null
                    : () => _confirmThenAssign(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmThenAssign(BuildContext context) async {
    final confirmed = await showProgramAssignConfirmDialog(
      context,
      clientName: clientName,
      registerDate: registerDate,
    );
    if (confirmed == true) onAssign();
  }

  /// 등록할 날짜를 고른다 — 기본값은 오늘, 과거 날짜는 고를 수 없다.
  Future<void> _pickDate(BuildContext context) async {
    final now = nowKst();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: registerDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    onRegisterDateChanged(DateTime(picked.year, picked.month, picked.day));
  }
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
          // 편집기와 같은 출처 배지 규칙(#1029) — 템플릿에서 온 운동은
          // `<템플릿명> 템플릿 추가` 로 보인다.
          if (exercise.templateName != null || exercise.source == 'trainer')
            Text(
              exercise.templateName != null
                  ? l.coachTemplateAdded(exercise.templateName!)
                  : l.coachTrainerAdded,
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
