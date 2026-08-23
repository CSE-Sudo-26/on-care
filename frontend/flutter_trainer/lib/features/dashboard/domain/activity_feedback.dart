import 'package:oncare_trainer/features/dashboard/domain/churn_risk.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// A kind of bullet on the "AI 진단" card's 트레이너 활동 피드백 list.
enum ActivityFeedbackKind {
  /// 개인 운동 이행률/이탈 위험 감지에 따른 난이도 조정 안내.
  difficultyReview,

  /// 7일 이상 활동 저조한 고객.
  inactiveSevenDays,

  /// 식단 주의 고객 피드백 미완료 안내.
  dietFeedbackPending;

  /// Short headline shown next to the leading icon.
  String title(AppLocalizations l) => switch (this) {
    ActivityFeedbackKind.difficultyReview => l.dashActivityDifficultyTitle,
    ActivityFeedbackKind.inactiveSevenDays => l.dashActivityInactiveTitle,
    ActivityFeedbackKind.dietFeedbackPending => l.dashActivityDietFeedbackTitle,
  };

  /// The full explanatory sentence — [names] woven in naturally ("{names}
  /// 고객이 ~해요") rather than tacked on as a separate "대상:" line.
  String description(AppLocalizations l, String names) => switch (this) {
    ActivityFeedbackKind.difficultyReview => l.dashActivityDifficultyDesc(
      names,
    ),
    ActivityFeedbackKind.inactiveSevenDays => l.dashActivityInactiveDesc(names),
    ActivityFeedbackKind.dietFeedbackPending => l.dashActivityDietFeedbackDesc(
      names,
    ),
  };

  /// A short clause telling the trainer *where* to act — woven into the
  /// end of [description] so the recommendation reads as part of the same
  /// sentence, not a separate instruction.
  String recommendation(AppLocalizations l) => switch (this) {
    ActivityFeedbackKind.difficultyReview => l.dashActivityRecommendRoutine,
    ActivityFeedbackKind.inactiveSevenDays => l.dashActivityRecommendChat,
    ActivityFeedbackKind.dietFeedbackPending => l.dashActivityRecommendDiet,
  };

  /// The destination tab's own name — the CTA is a short "프로그램 >" link,
  /// not a full sentence like "AI 루틴 만들러 가기". Each kind's fix lives
  /// on a different tab (프로그램, 메시지, 식단), so the label names that tab.
  String tabLabel(AppLocalizations l) => switch (this) {
    ActivityFeedbackKind.difficultyReview => l.dashActivityTabProgram,
    ActivityFeedbackKind.inactiveSevenDays => l.dashActivityTabChat,
    ActivityFeedbackKind.dietFeedbackPending => l.dashActivityTabDiet,
  };
}

/// One bullet on the "AI 진단" card's 트레이너 활동 피드백 list.
class ActivityFeedbackItem {
  /// Creates a feedback bullet.
  const ActivityFeedbackItem({
    required this.kind,
    required this.clientNames,
    required this.clientIds,
  });

  /// What this bullet is about.
  final ActivityFeedbackKind kind;

  /// Who triggered it — an empty list is a valid "none right now".
  final List<String> clientNames;

  /// Same order as [clientNames] — the CTA jumps to [clientIds].first, the
  /// client most worth checking first (`buildActivityFeedback`'s 로스터
  /// 순서 그대로).
  final List<String> clientIds;

  /// How many clients triggered this bullet.
  int get count => clientNames.length;
}

/// Builds the "AI 진단" card's activity-feedback bullets from the same
/// per-client signals [buildChurnRisk] uses — this list is deliberately
/// wider than 이탈 위험 (it surfaces every client with *any* one matching
/// signal, not only the ones that cross the 이탈 위험 threshold).
List<ActivityFeedbackItem> buildActivityFeedback({
  required List<TrainerClient> clients,
  required Map<String, List<ScheduleSession>> recentSessionsByClient,
  required Map<String, int> unread,
  required DateTime now,
}) {
  final difficultyReview = <TrainerClient>[];
  final inactiveSevenDays = <TrainerClient>[];
  final dietFeedbackPending = <TrainerClient>[];

  for (final client in clients.where((c) => c.active)) {
    final signals = computeChurnSignals(
      client,
      recentSessions:
          recentSessionsByClient[client.id] ?? const <ScheduleSession>[],
      unreadCount: unread[client.id] ?? 0,
      now: now,
    );

    if (signals.contains(ChurnSignal.noRecentWorkout) ||
        signals.contains(ChurnSignal.goalStagnant)) {
      difficultyReview.add(client);
    }

    if (signals.contains(ChurnSignal.noRecentWorkout)) {
      inactiveSevenDays.add(client);
    }

    if ((client.sodiumOverBudget || client.sugarOverBudget) &&
        signals.contains(ChurnSignal.noRecentFeedback)) {
      dietFeedbackPending.add(client);
    }
  }

  return <ActivityFeedbackItem>[
    _item(ActivityFeedbackKind.difficultyReview, difficultyReview),
    _item(ActivityFeedbackKind.inactiveSevenDays, inactiveSevenDays),
    _item(ActivityFeedbackKind.dietFeedbackPending, dietFeedbackPending),
  ];
}

ActivityFeedbackItem _item(
  ActivityFeedbackKind kind,
  List<TrainerClient> clients,
) => ActivityFeedbackItem(
  kind: kind,
  clientNames: <String>[for (final c in clients) c.name],
  clientIds: <String>[for (final c in clients) c.id],
);
