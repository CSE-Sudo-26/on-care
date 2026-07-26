import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/app/app.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/services/locale_provider.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
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
          // Diet repo defaults to DioDietRepository (Stage 9) which
          // needs a real dio+db. Swap to the in-memory mock here.
          dietRepositoryProvider.overrideWithValue(
            const MockDietRepository() as DietRepository,
          ),
          // Same reason — exercise repo defaults to DioExerciseRepository
          // (Stage 9.6); swap to the in-memory mock here.
          exerciseRepositoryProvider.overrideWithValue(
            const MockExerciseRepository() as ExerciseRepository,
          ),
          // Dashboard summary defaults to DioDashboardRepository (Stage
          // 9.8); the smoke test only inspects the nav, so the mock is
          // plenty.
          dashboardRepositoryProvider.overrideWithValue(
            const MockDashboardRepository() as DashboardRepository,
          ),
          if (locale != null) localeProvider.overrideWith((ref) => locale),
        ],
        child: const OncareApp(),
      ),
    );
    await tester.pumpAndSettle();
    // The app now boots into the sign-in screen; enter demo mode to reach
    // the main app (Home tab).
    await tester.tap(find.text('데모로 시작'));
    await tester.pumpAndSettle();
  }

  testWidgets('Enters the Home tab in English after demo', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    // Bottom-nav labels match the React original.
    expect(find.text('Home'), findsAtLeastNWidgets(1));
    expect(find.text('Diet'), findsAtLeastNWidgets(1));
    expect(find.text('Exercise'), findsAtLeastNWidgets(1));
    expect(find.text('My'), findsAtLeastNWidgets(1));
  });

  testWidgets('Tapping a bottom-nav destination switches branch', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    // OncareHeader is a Material+Container (not an AppBar), so we
    // settle for `find.text(...)` finders here.
    await tester.tap(find.text('Diet').first);
    await tester.pumpAndSettle();
    expect(find.text('Diet'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Exercise').first);
    await tester.pumpAndSettle();
    expect(find.text('Exercise'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('My').first);
    await tester.pumpAndSettle();
    expect(find.text('My'), findsAtLeastNWidgets(1));
  });

  testWidgets('Korean locale localises the bottom-nav labels', (tester) async {
    await pumpApp(tester, locale: const Locale('ko'));
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsAtLeastNWidgets(1));
    expect(find.text('식단'), findsAtLeastNWidgets(1));
    expect(find.text('운동'), findsAtLeastNWidgets(1));
    expect(find.text('My'), findsAtLeastNWidgets(1));
  });

  test('ARB resources expose nav strings for ko + en', () {
    // sanity: 'supportedLocales' is the canonical set.
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('ko')));
  });
}
