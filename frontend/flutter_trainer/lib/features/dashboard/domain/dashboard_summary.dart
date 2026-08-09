import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

export 'package:oncare_trainer/shared/models/client_alerts.dart'
    show AttentionClient, ClientAlert, lowCompletionThreshold;

/// Weekday labels for the 주간 이행률 chart, in the current locale.
/// [TrainerClient.weekCompletion] is indexed 월→일, matching
/// `DateTime.weekday` (월=1 … 일=7) minus one.
///
/// 함수인 이유: const 리스트로 두면 생성 시점에 로케일을 알 수 없다. (#501)
/// 주간 시리즈의 길이(월~일). 라벨과 달리 로케일과 무관한 숫자라 상수로 둔다.
const int weekdayCount = 7;

List<String> weekdayLabels(AppLocalizations l) => <String>[
  l.weekdayMon,
  l.weekdayTue,
  l.weekdayWed,
  l.weekdayThu,
  l.weekdayFri,
  l.weekdaySat,
  l.weekdaySun,
];

/// How many weekday slots of the current (월-start) week have actually
/// happened, counting today: 월요일이면 1, 목요일이면 4.
///
/// Everything that renders or averages a Mon–Sun series for *this* week
/// clips at this index. Without it a chart drawn on Thursday still shows
/// Fri/Sat/Sun, and whatever the source happens to hold for those days —
/// a seeded value, or a zero — reads as a real result.
int elapsedWeekdays(DateTime today) => today.weekday;

/// Everything the 대시보드 renders, derived from the same streams the
/// other tabs already use — no dedicated summary endpoint.
///
/// Kept as a plain value object built by [buildDashboardSummary] so the
/// aggregation rules (what counts as "주의", how the weekly average is
/// computed) are unit-testable without pumping a widget.
class DashboardSummary {
  /// Creates a summary.
  const DashboardSummary({
    required this.activeClients,
    required this.totalClients,
    required this.unreadTotal,
    required this.unreadClients,
    required this.attention,
    required this.weeklyCompletion,
  });

  /// Clients currently marked 활성.
  final int activeClients;

  /// Roster size.
  final int totalClients;

  /// Unread messages across all threads.
  final int unreadTotal;

  /// How many clients are waiting on a reply.
  final int unreadClients;

  /// Clients with something to act on today, most urgent first — health
  /// signals then unanswered messages.
  final List<AttentionClient> attention;

  /// How many of [attention] are there for a health reason.
  ///
  /// This is the 주의 고객 KPI. 답장 대기 stays in the list (the trainer
  /// still has to answer) but is not 주의 — counting it made all three
  /// seeded clients look like health concerns.
  int get healthAttentionCount =>
      attention.where((a) => a.alerts.any((x) => x.isHealth)).length;

  /// Mean routine completion (%) per weekday, 월→일. Empty when no
  /// client has weekly data yet.
  final List<int> weeklyCompletion;

  /// An empty summary — used while the streams are still loading.
  static const DashboardSummary empty = DashboardSummary(
    activeClients: 0,
    totalClients: 0,
    unreadTotal: 0,
    unreadClients: 0,
    attention: <AttentionClient>[],
    weeklyCompletion: <int>[],
  );
}

/// Aggregates the dashboard's numbers from the roster and unread counts.
///
/// [clients] is expected in coaching-priority order (the same ordering
/// the 고객 list uses); ties inside the attention list therefore keep
/// that order rather than inventing a second one.
DashboardSummary buildDashboardSummary({
  required List<TrainerClient> clients,
  required Map<String, int> unread,
}) {
  final attention = <AttentionClient>[];
  var unreadTotal = 0;
  var unreadClients = 0;

  for (final client in clients) {
    final pending = unread[client.id] ?? 0;
    if (pending > 0) {
      unreadTotal += pending;
      unreadClients++;
    }
    final alerts = alertsFor(client, unread: pending);
    if (alerts.isNotEmpty) {
      attention.add(AttentionClient(client: client, alerts: alerts));
    }
  }

  // Most urgent alert type first; within a type, keep the incoming
  // (coaching-priority) order. `List.sort` is not stable in Dart, so the
  // original position is the explicit tiebreaker.
  final order = <String, int>{
    for (var i = 0; i < clients.length; i++) clients[i].id: i,
  };
  attention.sort((a, b) {
    final byAlert = a.primary.index.compareTo(b.primary.index);
    if (byAlert != 0) return byAlert;
    return (order[a.client.id] ?? 0).compareTo(order[b.client.id] ?? 0);
  });

  return DashboardSummary(
    activeClients: clients.where((c) => c.active).length,
    totalClients: clients.length,
    unreadTotal: unreadTotal,
    unreadClients: unreadClients,
    attention: attention,
    weeklyCompletion: _meanWeeklyCompletion(clients),
  );
}

/// Mean completion per weekday across every client that has a full week
/// of data. Days no client recorded stay 0.
List<int> _meanWeeklyCompletion(List<TrainerClient> clients) {
  final weeks = clients
      .map((c) => c.weekCompletion)
      .where((w) => w.length == weekdayCount)
      .toList();
  if (weeks.isEmpty) return const <int>[];
  return <int>[
    for (var day = 0; day < weekdayCount; day++)
      (weeks.map((w) => w[day]).reduce((a, b) => a + b) / weeks.length).round(),
  ];
}
