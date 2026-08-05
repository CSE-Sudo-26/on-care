import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// 주간 소모 칼로리 목표(kcal). 홈 운동 카드와 운동 탭이 같은 목표치를 보여야
/// 하는데 값의 출처가 대시보드 요약이라, 운동 화면이 `features/dashboard` 의
/// provider 를 직접 구독하며 대시보드의 상태 수명·API 에 결합돼 있었다.
///
/// 그 의존을 이 한 곳으로 모아, 목표치를 쓰는 feature 는 "int 하나" 라는 계약만
/// 본다. 값의 출처가 바뀌어도(개인화 API 신설 등) 고칠 곳은 여기뿐이다.
///
/// 요약이 로딩 중이거나 실패하면 엔티티 기본값을 돌려준다 — 목표치 하나 때문에
/// 운동 화면 전체가 로딩·에러 상태로 빠지지 않게 한다.
final exerciseBurnGoalProvider = Provider<int>(
  (ref) =>
      ref.watch(dashboardSummaryProvider).valueOrNull?.exerciseBurnGoal ??
      DashboardSummary.defaultExerciseBurnGoal,
  name: 'exerciseBurnGoal',
);
