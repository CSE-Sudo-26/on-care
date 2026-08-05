import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/shared/services/exercise_burn_goal_provider.dart';

void main() {
  DashboardSummary summaryWithGoal(int goal) => DashboardSummary(
    indicators: const <HealthIndicator>[],
    macros: const DietMacros.zero(),
    dietEntries: 0,
    exerciseMinutes: 0,
    exerciseBurnGoal: goal,
    todaySchedule: const <ScheduleItem>[],
    weekScore: 0,
    weekScoreDelta: 0,
    sodiumWarning: null,
  );

  ProviderContainer containerWith(
    Future<DashboardSummary> Function() load,
  ) {
    final container = ProviderContainer(
      overrides: <Override>[
        dashboardSummaryProvider.overrideWith((ref) => load()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('요약이 내려준 목표치를 그대로 노출한다', () async {
    final container = containerWith(() async => summaryWithGoal(800));
    await container.read(dashboardSummaryProvider.future);

    expect(container.read(exerciseBurnGoalProvider), 800);
  });

  test('로딩 중에는 엔티티 기본값으로 버틴다', () {
    // 목표치 하나 때문에 운동 화면이 로딩 상태로 빠지면 안 된다.
    final container = containerWith(() => Completer<DashboardSummary>().future);

    expect(
      container.read(exerciseBurnGoalProvider),
      DashboardSummary.defaultExerciseBurnGoal,
    );
  });

  test('요약 조회가 실패해도 엔티티 기본값으로 버틴다', () async {
    final container = containerWith(
      () => Future<DashboardSummary>.error(StateError('boom')),
    );
    await expectLater(
      container.read(dashboardSummaryProvider.future),
      throwsStateError,
    );

    expect(
      container.read(exerciseBurnGoalProvider),
      DashboardSummary.defaultExerciseBurnGoal,
    );
  });

  test('요약이 갱신되면 목표치도 따라 바뀐다', () async {
    // 한 번 읽고 마는 스냅샷이 아니라 요약을 계속 구독하는지 확인한다.
    int goal = 800;
    final container = containerWith(() async => summaryWithGoal(goal));
    await container.read(dashboardSummaryProvider.future);
    expect(container.read(exerciseBurnGoalProvider), 800);

    goal = 650;
    await container.refresh(dashboardSummaryProvider.future);

    expect(container.read(exerciseBurnGoalProvider), 650);
  });
}
