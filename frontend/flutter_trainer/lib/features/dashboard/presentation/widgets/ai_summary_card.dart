import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/activity_feedback.dart';
import 'package:oncare_trainer/features/dashboard/domain/ai_coaching_summary.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/oni_avatar.dart';

/// 식단·운동·건강 프로필·최근 대화를 고객별 실행 항목으로 보여 주는 요약 카드.
class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    super.key,
    required this.summary,
    required this.onRetry,
    this.activityFeedback = const <ActivityFeedbackItem>[],
  });

  final AsyncValue<AiCoachingSummary> summary;
  final VoidCallback onRetry;

  /// 트레이너 활동 피드백 bullets — 이행률·이탈 위험·식단 피드백 미완료 등.
  final List<ActivityFeedbackItem> activityFeedback;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.aiCardGradientEnd),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.aiCardGradientStart, AppColors.bannerEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(title: l.dashAiSummaryTitle, today: l.dashToday),
          if (activityFeedback.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _ActivityFeedbackList(items: activityFeedback),
          ],
          const SizedBox(height: AppSpacing.md),
          summary.when(
            loading: () => _LoadingState(label: l.dashAiLoading),
            error: (error, _) => _ErrorState(
              label: error is RateLimitedError
                  ? l.dashAiRateLimited
                  : l.dashAiLoadFailed,
              retryLabel: l.actionRetry,
              onRetry: onRetry,
            ),
            data: (value) => _SummaryBody(summary: value),
          ),
          const SizedBox(height: AppSpacing.md),
          ActionButton(
            label: l.dashCreateAiRoutine,
            icon: Icons.auto_awesome,
            primary: true,
            onPressed: () => context.go(AppRoutes.coaching),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.today});

  final String title;
  final String today;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const OniAvatar(size: 28),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.all(AppRadius.pill),
          ),
          child: Text(
            today,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// "AI 진단" 카드 헤더 아래의 트레이너 활동 피드백 — 이행률·이탈 위험·식단
/// 피드백 등 오늘 트레이너가 챙길 만한 사항을 짧은 불릿으로 짚어 준다.
class _ActivityFeedbackList extends StatelessWidget {
  const _ActivityFeedbackList({required this.items});

  final List<ActivityFeedbackItem> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.9),
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: const BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.dashActivityFeedbackTitle,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 5, right: AppSpacing.xs),
                    child: Icon(
                      Icons.circle,
                      size: 4,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.kind.label(l, item.count),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
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

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final AiCoachingSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final headline = switch (summary.kind) {
      CoachingSummaryKind.noClients => l.dashAiNoClients,
      CoachingSummaryKind.allOnTrack => l.dashAiAllOnTrack(
        summary.totalClients,
      ),
      CoachingSummaryKind.attention => l.dashAiRuleHeadline(
        summary.clients.first.memberName,
      ),
      CoachingSummaryKind.details => summary.headline,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          headline,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
        if (summary.clients.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 960
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  for (final insight in summary.clients)
                    SizedBox(
                      width: width,
                      child: _InsightPanel(insight: insight),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.insight});

  final AiCoachingClientInsight insight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final copy = _insightCopy(l, insight);
    final (priorityLabel, priorityColor) = switch (insight.priority) {
      CoachingPriority.high => (l.dashAiPriorityHigh, AppColors.warning),
      CoachingPriority.medium => (
        l.dashAiPriorityMedium,
        AppColors.brandOrange,
      ),
      CoachingPriority.low => (l.dashAiPriorityLow, AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.9),
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: const BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  insight.memberName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                ),
                child: Text(
                  priorityLabel,
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailBlock(
            icon: Icons.monitor_heart_outlined,
            label: l.dashAiStatus,
            body: copy.status,
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailBlock(
            icon: Icons.fitness_center,
            label: l.dashAiExerciseFocus,
            body: copy.focus,
          ),
          if (copy.evidence.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _DetailBlock(
              icon: Icons.fact_check_outlined,
              label: l.dashAiEvidence,
              body: copy.evidence.map((item) => '• $item').join('\n'),
            ),
          ],
          if (copy.caution.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _DetailBlock(
              icon: Icons.health_and_safety_outlined,
              label: l.dashAiCaution,
              body: copy.caution,
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightCopy {
  const _InsightCopy({
    required this.status,
    required this.focus,
    required this.evidence,
    required this.caution,
  });

  final String status;
  final String focus;
  final List<String> evidence;
  final String caution;
}

_InsightCopy _insightCopy(AppLocalizations l, AiCoachingClientInsight insight) {
  final data = insight.ruleData;
  if (data == null) {
    return _InsightCopy(
      status: insight.statusSummary,
      focus: insight.exerciseFocus,
      evidence: insight.evidence,
      caution: insight.caution,
    );
  }
  final (status, focus, caution) = switch (data.signal) {
    RuleCoachingSignal.knee => (
      l.dashAiRuleKneeStatus,
      l.dashAiRuleKneeFocus,
      l.dashAiRuleKneeCaution,
    ),
    RuleCoachingSignal.upperBody => (
      l.dashAiRuleUpperStatus,
      l.dashAiRuleUpperFocus,
      l.dashAiRuleUpperCaution,
    ),
    RuleCoachingSignal.fatigue => (
      l.dashAiRuleFatigueStatus,
      l.dashAiRuleFatigueFocus,
      l.dashAiRuleFatigueCaution,
    ),
    RuleCoachingSignal.sodium => (
      l.dashAiRuleSodiumStatus,
      l.dashAiRuleSodiumFocus,
      l.dashAiRuleSodiumCaution,
    ),
    RuleCoachingSignal.lowCompletion => (
      l.dashAiRuleCompletionStatus,
      l.dashAiRuleCompletionFocus,
      l.dashAiRuleCompletionCaution,
    ),
    RuleCoachingSignal.unanswered => (
      l.dashAiRuleUnansweredStatus,
      l.dashAiRuleUnansweredFocus,
      l.dashAiRuleUnansweredCaution,
    ),
  };
  final evidence = <String>[
    if (data.recentMessage case final message?)
      l.dashAiRuleEvidenceMessage(message),
    if ((data.sodiumMg, data.sodiumTargetMg) case (final value?, final target?))
      l.dashAiRuleEvidenceSodium(value, target),
    if (data.completionAverage case final average?)
      l.dashAiRuleEvidenceCompletion(average),
  ];
  return _InsightCopy(
    status: status,
    focus: focus,
    evidence: evidence.take(3).toList(growable: false),
    caution: caution,
  );
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.icon,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.label,
    required this.retryLabel,
    required this.onRetry,
  });

  final String label;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}
