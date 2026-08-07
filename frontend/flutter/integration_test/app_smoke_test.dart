import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/app/app.dart';
import 'package:oncare/app/session_feature_reset.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/shared/services/locale_provider.dart';

/// Run on a device/emulator with:
///   flutter test integration_test/app_smoke_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots into Dashboard and tabs are reachable', (
    tester,
  ) async {
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
          sessionFeatureResetOverride(),
          localeProvider.overrideWith((ref) => const Locale('en')),
        ],
        child: const OncareApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Boot into Dashboard.
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Tap each non-Dashboard tab and verify the title changes.
    for (final ({String label, String title}) tab
        in const <({String label, String title})>[
          (label: 'Diet', title: 'Diet Record'),
          (label: 'Exercise', title: 'Exercise'),
          (label: 'My Health', title: 'My Health'),
        ]) {
      await tester.tap(find.text(tab.label).first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, tab.title), findsOneWidget);
    }
  });
}
