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

  /// The full explanatory sentence — what this signal means and what to
  /// do about it.
  String description(AppLocalizations l) => switch (this) {
    ActivityFeedbackKind.difficultyReview => l.dashActivityDifficultyDesc,
    ActivityFeedbackKind.inactiveSevenDays => l.dashActivityInactiveDesc,
    ActivityFeedbackKind.dietFeedbackPending => l.dashActivityDietFeedbackDesc,
  };
}

/// One bullet on the "AI 진단" card's 트레이너 활동 피드백 list.
class ActivityFeedbackItem {
  /// Creates a feedback bullet.
  const ActivityFeedbackItem({required this.kind, required this.clientNames});

  /// What this bullet is about.
  final ActivityFeedbackKind kind;

  /// Who triggered it — an empty list is a valid "none right now".
  final List<String> clientNames;

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
  final difficultyReview = <String>[];
  final inactiveSevenDays = <String>[];
  final dietFeedbackPending = <String>[];

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
      difficultyReview.add(client.name);
    }

    if (signals.contains(ChurnSignal.noRecentWorkout)) {
      inactiveSevenDays.add(client.name);
    }

    if ((client.sodiumOverBudget || client.sugarOverBudget) &&
        signals.contains(ChurnSignal.noRecentFeedback)) {
      dietFeedbackPending.add(client.name);
    }
  }

  return <ActivityFeedbackItem>[
    ActivityFeedbackItem(
      kind: ActivityFeedbackKind.difficultyReview,
      clientNames: difficultyReview,
    ),
    ActivityFeedbackItem(
      kind: ActivityFeedbackKind.inactiveSevenDays,
      clientNames: inactiveSevenDays,
    ),
    ActivityFeedbackItem(
      kind: ActivityFeedbackKind.dietFeedbackPending,
      clientNames: dietFeedbackPending,
    ),
  ];
}
