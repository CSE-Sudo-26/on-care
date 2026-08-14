import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/features/dashboard/data/ai_coaching_summary_repository.dart';
import 'package:oncare_trainer/features/dashboard/domain/ai_coaching_summary.dart';
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

/// 상세 코칭 요약은 별도 실패 경계를 둔다. LLM/API가 느리거나 실패해도 KPI와
/// 일정은 즉시 표시되고, 카드 안에서만 로딩·재시도를 제공한다.
final dashboardAiCoachingSummaryProvider = FutureProvider<AiCoachingSummary>((
  ref,
) async {
  final repository = ref.watch(aiCoachingSummaryRepositoryProvider);
  if (!ref.watch(appConfigProvider).useMockApi) {
    return repository.fetch(DashboardSummary.empty);
  }

  final clients = await ref.watch(clientsProvider.future);
  final unread =
      ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
  return repository.fetch(
    buildDashboardSummary(clients: clients, unread: unread),
  );
});
