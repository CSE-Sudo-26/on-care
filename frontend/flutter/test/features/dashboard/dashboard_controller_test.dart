import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';

class _FailingDashboardRepository implements DashboardRepository {
  const _FailingDashboardRepository();

  @override
  Future<DashboardSummary> fetchSummary() async {
    throw StateError('boom');
  }
}

void main() {
  test('dashboardSummaryProvider returns mock indicators + schedule', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        // Default impl is DioDashboardRepository (Stage 9.8). For
        // this unit test the React-shaped mock is enough.
        dashboardRepositoryProvider.overrideWithValue(
          const MockDashboardRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final summary = await container.read(dashboardSummaryProvider.future);
    expect(summary, isA<DashboardSummary>());
    // 혈당 row was dropped from the home summary; expect 3 rows
    // (칼로리 / 나트륨 / 당류).
    expect(summary.indicators.length, 3);
    expect(summary.todaySchedule.length, 2);
    expect(summary.weekScore, 85);
  });

  test('dashboardSummaryProvider propagates repository failures', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        dashboardRepositoryProvider.overrideWithValue(
          const _FailingDashboardRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(dashboardSummaryProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  test('MockDashboardRepository marks sodium as over-budget', () async {
    const repo = MockDashboardRepository();
    final s = await repo.fetchSummary();
    final sodium = s.indicators.firstWhere(
      (HealthIndicator h) => h.label == '나트륨',
    );
    expect(sodium.overBudget, isTrue);
    expect(sodium.progress, 1.0); // clamped
  });
}
