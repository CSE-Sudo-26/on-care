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
    expect(summary.exerciseMinutes, 45);
    expect(summary.exerciseCalories, 520);
    expect(summary.exerciseCount, 4);
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
    expect(s.macros.carbsG, 203.6);
    expect(s.macros.proteinG, 109.3);
    expect(s.macros.fatG, 66.5);
  });

  test('DashboardSummary parses macros and supports older responses', () {
    Map<String, Object?> payload({Map<String, Object?>? macros}) {
      final result = <String, Object?>{
        'indicators': <Object?>[],
        'diet_entries': 0,
        'exercise_minutes': 0,
        'today_schedule': <Object?>[],
        'week_score': 50,
        'week_score_delta': 0,
        'sodium_warning': null,
        'exercise_feedback': null,
      };
      if (macros != null) result['macros'] = macros;
      return result;
    }

    final parsed = DashboardSummary.fromJson(
      payload(
        macros: <String, Object?>{
          'carbs_g': 203.6,
          'protein_g': 109.3,
          'fat_g': 66.5,
          'carbs_pct': 44,
          'protein_pct': 24,
          'fat_pct': 32,
        },
      ),
    );
    expect(parsed.macros.carbsG, 203.6);
    expect(parsed.macros.carbsPct, 44);
    expect(parsed.exerciseCalories, 0);
    expect(parsed.exerciseCount, 0);

    final legacy = DashboardSummary.fromJson(payload());
    expect(legacy.macros.carbsG, 0);
    expect(legacy.macros.carbsPct, 0);
    expect(legacy.isEmpty, isTrue);
  });
}
