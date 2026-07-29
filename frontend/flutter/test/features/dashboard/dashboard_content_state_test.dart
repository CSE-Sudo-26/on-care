import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required Future<DashboardSummary> Function() load,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          profileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'member',
              name: '테스트',
              email: 'member@example.com',
            ),
          ),
          dashboardSummaryProvider.overrideWith((ref) => load()),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DashboardContent()),
        ),
      ),
    );
  }

  testWidgets('shows loading state', (WidgetTester tester) async {
    final completer = Completer<DashboardSummary>();
    await pumpDashboard(tester, load: () => completer.future);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error state', (WidgetTester tester) async {
    await pumpDashboard(
      tester,
      load: () => Future<DashboardSummary>.error(StateError('boom')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('대시보드 정보를 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('shows empty state with zero values', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      load: () async => const DashboardSummary(
        indicators: <HealthIndicator>[
          HealthIndicator(label: '칼로리', current: 0, max: 2000, unit: 'kcal'),
          HealthIndicator(label: '나트륨', current: 0, max: 2000, unit: 'mg'),
          HealthIndicator(label: '당류', current: 0, max: 50, unit: 'g'),
        ],
        macros: DietMacros.zero(),
        dietEntries: 0,
        exerciseMinutes: 0,
        todaySchedule: <ScheduleItem>[],
        weekScore: 50,
        weekScoreDelta: 0,
        sodiumWarning: null,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('아직 오늘 기록이 없어요. 식단이나 운동을 기록해 보세요.'), findsOneWidget);
    expect(find.text('오늘 예정된 일정이 없어요.'), findsOneWidget);
    expect(find.text('0.0g'), findsNWidgets(3));
  });
}
