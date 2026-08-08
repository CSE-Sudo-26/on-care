import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/dashboard/data/repositories/dio_dashboard_repository.dart';
import 'package:oncare/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  // diet·exercise·my_health 와 같은 분기. 이 갈래가 없으면 백엔드 미연결
  // 데모에서 홈이 "대시보드 정보를 불러오지 못했어요" 만 띄운다.
  if (ref.watch(appConfigProvider).useMockApi) {
    // 영양 수치는 식단 저장소가 기준이다. 같은 인스턴스를 넘겨야 데모 중
    // 식단 CRUD 가 홈 요약에도 반영된다(#294 의 세션 상태 유지).
    //
    // [dietTodayProvider] 도 함께 watch 한다. `MockDietRepository` 는 세션 동안
    // 상태를 들고 있어 CRUD 로 내용만 바뀌므로, 저장소만 봐서는 홈이 옛 수치를
    // 계속 보여준다. 식단 CRUD 는 전부 그 provider 를 무효화하니(6곳) 여기에
    // 한 번 걸어 두면 새 CRUD 자리가 생겨도 따라온다 — 자리마다 invalidate 를
    // 흩뿌리면 다음 자리에서 또 빠진다(CodeRabbit 리뷰).
    ref.watch(dietTodayProvider);
    return MockDashboardRepository(ref.watch(dietRepositoryProvider));
  }
  return DioDashboardRepository(ref.watch(dioProvider));
}, name: 'dashboardRepository');

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchSummary();
}, name: 'dashboardSummary');
