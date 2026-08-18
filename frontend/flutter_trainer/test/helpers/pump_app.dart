import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oncare_trainer/app/app.dart';
import 'package:oncare_trainer/app/router/app_router.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';

/// Mock-mode config so widget tests resolve the in-memory repositories
/// (no real backend). Individual tests can override with [extraOverrides].
const AppConfig kTestAppConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost/v1',
  useMockApi: true,
);

/// Pumps the full trainer app for a widget test, backed by a fresh
/// in-memory (seeded) drift DB and an optional persisted session token.
///
/// Returns the [ProviderContainer] so tests can read providers directly.
///
/// NOTE: uses bounded `pump()`s rather than `pumpAndSettle()` — pages
/// backed by a drift `.watch()` stream keep a live subscription, so
/// `pumpAndSettle` never reaches an idle frame and times out. Two pumps
/// (one to build, one to let the stream emit + route transition finish)
/// are enough for the seeded data to render.
/// [bootAt] boots the router at a location instead of the platform one —
/// the widget-test stand-in for opening the console on a deep link (a
/// browser refresh or a shared URL). It differs from [at], which
/// navigates *after* the app is up and so never exercises the boot path.
/// [seedClock] 을 주면 데모 시딩이 그 날짜를 '오늘' 로 삼는다.
///
/// 시드는 주간 계열을 **오늘까지만** 채운다(`_upToToday`). 그래서 요일에 따라
/// 그 주에 기록된 날의 수가 달라지고, 이행률 평균이 달라지고, 배지의 우선순위가
/// 뒤집힌다. 특정 배지를 검증하는 테스트는 요일을 고정해야 어느 날 돌려도 같은
/// 값을 본다.
Future<ProviderContainer> pumpTrainerApp(
  WidgetTester tester, {
  String? token,
  bool seed = true,
  String? at,
  String? bootAt,
  List<Override> extraOverrides = const <Override>[],
  Locale locale = const Locale('ko'),
  DateTime? seedClock,
}) async {
  // A persisted session lives in secure storage now (access + refresh).
  // Reset the in-memory mock per test so state never leaks between them.
  FlutterSecureStorage.setMockInitialValues(
    token == null
        ? <String, String>{}
        : <String, String>{'access_token': token, 'refresh_token': '$token-r'},
  );
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  if (seed) await seedIfEmpty(db, clock: seedClock);
  addTearDown(() async => db.close());

  final container = ProviderContainer(
    overrides: <Override>[
      appConfigProvider.overrideWithValue(kTestAppConfig),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      if (bootAt != null)
        routerInitialLocationProvider.overrideWithValue(bootAt),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OncareTrainerApp(locale: locale),
    ),
  );
  await settle(tester);
  if (at != null) await goTo(tester, at);
  return container;
}

/// Navigates the pumped app to [location] and settles.
///
/// Tests drive navigation through the router rather than by tapping the
/// sidebar: the console's nav is only in the tree above
/// [AppLayout.sidebarDrawerBreakpoint] (below that it lives in a
/// drawer), and the default 800x600 test surface is under that. Going by
/// location also keeps the tests honest about the URL contract.
Future<void> goTo(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Navigator).first);
  GoRouter.of(context).go(location);
  await settle(tester);
}

/// The location the pumped app is currently showing, query included —
/// the URL contract a browser refresh has to reproduce.
String currentLocation(WidgetTester tester) {
  final context = tester.element(find.byType(Navigator).first);
  return GoRouter.of(context).routeInformationProvider.value.uri.toString();
}

/// Runs [body] with a desktop-sized surface so the console renders its
/// expanded sidebar and any master-detail split, then restores the
/// default. Use for anything that asserts on the split layout.
Future<void> withWideSurface(
  WidgetTester tester,
  Future<void> Function() body, {
  Size size = const Size(1440, 900),
}) async {
  // Set the view directly (not `setSurfaceSize`): the shell reads
  // `MediaQuery.sizeOf`, which is derived from the view's physical size
  // and DPR, and a DPR of 1 keeps logical == physical so the numbers in
  // the test match the breakpoints in `AppLayout`.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await body();
}

/// Bounded settle for drift-stream-backed pages. `pumpAndSettle` never
/// idles here (a live `.watch()` subscription keeps a frame scheduled),
/// so instead we pump a fixed number of frames — enough for async chains
/// like mock-login delay → redirect → route transition → stream emit to
/// complete, without the infinite wait.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
