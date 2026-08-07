import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/dashboard/data/repositories/dio_dashboard_repository.dart';
import 'package:oncare/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  // diet·exercise·my_health 와 같은 분기. 이 갈래가 없으면 백엔드 미연결
  // 데모에서 홈이 "대시보드 정보를 불러오지 못했어요" 만 띄운다.
  if (ref.watch(appConfigProvider).useMockApi) {
    return const MockDashboardRepository();
  }
  return DioDashboardRepository(ref.watch(dioProvider));
}, name: 'dashboardRepository');

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchSummary();
}, name: 'dashboardSummary');
