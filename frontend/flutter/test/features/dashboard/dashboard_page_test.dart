import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/app/app.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/shared/services/locale_provider.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
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
        ],
        child: const OncareApp(),
      ),
    );
    await tester.pumpAndSettle();
    // The app now boots into the sign-in screen; enter demo mode to reach
    // the dashboard. Find by Key (locale-independent) and scroll it into view
    // first (it sits below the fold on the compact test surface).
    final demoButton = find.byKey(const Key('demoEnterButton'));
    await tester.ensureVisible(demoButton);
    await tester.pumpAndSettle();
    await tester.tap(demoButton);
    await tester.pumpAndSettle();
  }

  testWidgets('Dashboard renders the current localized sections', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('오늘도 가볍게 시작해요 👋'), findsOneWidget);
    expect(find.text('식단 · 영양'), findsOneWidget);
    expect(find.text('오늘의 일정'), findsOneWidget);
    expect(find.text('저녁 산책'), findsOneWidget);
  });
}
