import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Roster filters reachable from the URL (`/clients?f=unread`).
///
/// The dashboard's KPI cards deep-link straight into these, so the
/// filter is part of the address rather than page-local state — "답장
/// 필요 3건" and the list it opens are the same claim, and a refresh or
/// a shared link must keep showing it.
enum ClientFilter {
  /// Everyone on the roster.
  all('all', '전체'),

  /// Clients with unanswered messages.
  unread('unread', '답장 필요'),

  /// Clients with any [ClientAlert] raised.
  attention('attention', '주의 고객');

  const ClientFilter(this.query, this.label);

  /// Value used in the `f` query parameter.
  final String query;

  /// Chip label.
  final String label;
}

/// Parses the `f` query parameter; anything unrecognised (including
/// null) falls back to [ClientFilter.all] rather than erroring — a stale
/// bookmark should show the roster, not a broken page.
ClientFilter clientFilterFrom(String? raw) {
  for (final filter in ClientFilter.values) {
    if (filter.query == raw) return filter;
  }
  return ClientFilter.all;
}

/// Applies [filter] to [clients], preserving the incoming order.
List<TrainerClient> applyClientFilter(
  List<TrainerClient> clients,
  ClientFilter filter, {
  required Map<String, int> unread,
}) {
  switch (filter) {
    case ClientFilter.all:
      return clients;
    case ClientFilter.unread:
      return clients.where((c) => (unread[c.id] ?? 0) > 0).toList();
    case ClientFilter.attention:
      return clients
          .where((c) => alertsFor(c, unread: unread[c.id] ?? 0).isNotEmpty)
          .toList();
  }
}
