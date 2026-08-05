import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Weekly completion below this (%) counts as a client who needs the
/// trainer to step in.
const int lowCompletionThreshold = 60;

/// Why a client needs attention. Ordered by urgency — [unanswered] first,
/// since a waiting member is the one thing only the trainer can fix.
///
/// Lives in `shared` because two features ask the same question: the
/// 대시보드 (who do I chase today?) and the 고객 list filter (show me
/// only those). One definition, so the dashboard count and the filtered
/// list can never disagree.
enum ClientAlert {
  /// The member sent messages the trainer hasn't answered.
  unanswered('답장 대기'),

  /// Today's sodium is over the daily target.
  sodiumOver('나트륨 초과'),

  /// This week's routine completion is low.
  lowCompletion('이행률 저조');

  const ClientAlert(this.label);

  /// Badge text shown next to the client's name.
  final String label;
}

/// A client that needs attention, with the reasons.
class AttentionClient {
  /// Creates an attention entry.
  const AttentionClient({required this.client, required this.alerts});

  /// The client.
  final TrainerClient client;

  /// Why they surfaced, most urgent first.
  final List<ClientAlert> alerts;

  /// The reason shown as the row's badge.
  ClientAlert get primary => alerts.first;
}

/// Every alert raised for [client], most urgent first. Empty means the
/// client is fine today.
List<ClientAlert> alertsFor(TrainerClient client, {int unread = 0}) {
  return <ClientAlert>[
    if (unread > 0) ClientAlert.unanswered,
    if (client.sodiumOverBudget) ClientAlert.sodiumOver,
    if (isLowCompletion(client)) ClientAlert.lowCompletion,
  ];
}

/// Whether [client]'s recorded week averages under
/// [lowCompletionThreshold].
///
/// Clients with no data yet (empty week / all zeros) are NOT flagged —
/// a client registered this morning would otherwise show up as failing
/// on day one, which trains the trainer to ignore the badge.
bool isLowCompletion(TrainerClient client) {
  final recorded = client.weekCompletion.where((d) => d > 0).toList();
  if (recorded.isEmpty) return false;
  final mean = recorded.reduce((a, b) => a + b) / recorded.length;
  return mean < lowCompletionThreshold;
}
