import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oncare_trainer/app/app.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';

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
Future<ProviderContainer> pumpTrainerApp(
  WidgetTester tester, {
  String? token,
  bool seed = true,
  List<Override> extraOverrides = const <Override>[],
}) async {
  final values = <String, Object>{};
  if (token != null) values['trainer_access_token'] = token;
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  if (seed) await seedIfEmpty(db);
  addTearDown(() async => db.close());

  final container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const OncareTrainerApp(),
    ),
  );
  await settle(tester);
  return container;
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
