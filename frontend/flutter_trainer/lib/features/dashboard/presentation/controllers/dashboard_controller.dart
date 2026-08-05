import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

/// The 대시보드's aggregated numbers.
///
/// Composed on the client from the streams the other tabs already
/// subscribe to ([prioritizedClientsProvider], [unreadCountsProvider])
/// rather than a dedicated `/trainer/summary` endpoint: with a roster of
/// this size the aggregation is free, and one fewer endpoint is one
/// fewer thing to keep in sync. If the roster ever grows past a few
/// hundred, move [buildDashboardSummary] behind a server call.
///
/// Unread counts are folded in as a plain value (not awaited): the
/// roster is what gates the dashboard, and a still-loading unread map
/// just means the 답장 필요 count starts at 0 and fills in.
final dashboardSummaryProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  final clients = ref.watch(prioritizedClientsProvider);
  final unread =
      ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
  return clients.whenData(
    (list) => buildDashboardSummary(clients: list, unread: unread),
  );
});
