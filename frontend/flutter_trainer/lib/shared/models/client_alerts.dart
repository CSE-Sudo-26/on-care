import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Weekly completion below this (%) counts as a client who needs the
/// trainer to step in.
const int lowCompletionThreshold = 60;

/// A reason a client's row is flagged, ordered by urgency.
///
/// Lives in `shared` because two features ask the same question: the
/// 대시보드 (who do I chase today?) and the 고객 list filter (show me
/// only those). One definition, so the dashboard count and the filtered
/// list can never disagree.
enum ClientAlert {
  /// Today's sodium is over the daily target.
  sodiumOver('나트륨 초과'),

  /// This week's routine completion is low.
  lowCompletion('이행률 저조'),

  /// The member sent messages the trainer hasn't answered.
  ///
  /// Last on purpose: a client's badge is their first alert, and while a
  /// waiting message is urgent, it is also the one the 답장 필요 counter
  /// already shows. Putting it first hid every sodium overshoot behind it.
  unanswered('답장 대기');

  const ClientAlert(this.label);

  /// Badge text shown next to the client's name.
  final String label;

  /// Whether this is a signal from the member's own health data.
  ///
  /// The 주의 고객 count is health only — an unanswered message is the
  /// trainer's own inbox, and counting it as 주의 made every client with
  /// a message look like a health concern. The list itself still shows
  /// 답장 대기 rows; it just doesn't call them 주의.
  bool get isHealth => this != ClientAlert.unanswered;
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
///
/// This is the full picture — what the 오늘 챙길 고객 list and the client
/// detail header show. For the 주의 고객 *count* use [healthAlertsFor].
List<ClientAlert> alertsFor(TrainerClient client, {int unread = 0}) {
  return <ClientAlert>[
    if (client.sodiumOverBudget) ClientAlert.sodiumOver,
    if (isLowCompletion(client)) ClientAlert.lowCompletion,
    if (unread > 0) ClientAlert.unanswered,
  ];
}

/// The subset of [alertsFor] that comes from the member's health data.
List<ClientAlert> healthAlertsFor(TrainerClient client) =>
    alertsFor(client).where((a) => a.isHealth).toList();

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
