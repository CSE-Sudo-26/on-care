import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/dashboard/data/repositories/dio_dashboard_repository.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DioDashboardRepository(ref.watch(dioProvider)),
  name: 'dashboardRepository',
);

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchSummary();
}, name: 'dashboardSummary');
