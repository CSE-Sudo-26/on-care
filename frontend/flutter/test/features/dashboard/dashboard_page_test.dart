import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/app/app.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/shared/services/locale_provider.dart';

class _StubDashboardRepository implements DashboardRepository {
  const _StubDashboardRepository();
  @override
  Future<DashboardSummary> fetchSummary() async => const DashboardSummary(
    indicators: <HealthIndicator>[
      HealthIndicator(label: 'A', current: 1, max: 2, unit: 'u'),
    ],
    dietEntries: 2,
    exerciseMinutes: 45,
    todaySchedule: <ScheduleItem>[
      ScheduleItem(time: '10:00', title: '병원 정기검진', emoji: '🏥'),
    ],
    weekScore: 85,
    weekScoreDelta: 12,
    sodiumWarning: null,
  );
}

class _FailingDashboardRepository implements DashboardRepository {
  const _FailingDashboardRepository();
  @override
  Future<DashboardSummary> fetchSummary() async {
    throw StateError('boom');
  }
}

void main() {
  Future<void> pumpApp(WidgetTester tester, DashboardRepository repo) async {
    // Five stacked dashboard cards — give the surface enough height so
    // the bottom ones stay attached (ListView lazy-builds otherwise).
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const config = AppConfig(
      environment: Environment.dev,
      apiBaseUrl: 'https://dev.api.test',
      useMockApi: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(config),
          appLoggerProvider.overrideWithValue(Logger(level: Level.off)),
          localeProvider.overrideWith((ref) => const Locale('ko')),
          dashboardRepositoryProvider.overrideWithValue(repo),
        ],
        child: const OncareApp(),
      ),
    );
    await tester.pumpAndSettle();
    // The app now boots into the sign-in screen; enter demo mode to reach
    // the dashboard.
    await tester.tap(find.text('데모로 시작'));
    await tester.pumpAndSettle();
  }

  testWidgets('Dashboard data path renders schedule + week score', (
    tester,
  ) async {
    await pumpApp(tester, const _StubDashboardRepository());
    expect(find.text('오늘도 건강한 하루 되세요 ☀️'), findsOneWidget);
    expect(find.text('오늘의 건강 기록'), findsOneWidget);
    expect(find.text('병원 정기검진'), findsOneWidget);
    expect(find.text('85점'), findsOneWidget);
  });

  testWidgets('Dashboard error path shows ErrorView retry button', (
    tester,
  ) async {
    await pumpApp(tester, const _FailingDashboardRepository());
    expect(find.text('다시 시도'), findsOneWidget);
  });
}
