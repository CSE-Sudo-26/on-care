import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/app/app.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single entry point used by `main.dart`. Initializes the binding,
/// resolves the async services the widget tree needs synchronously
/// (SharedPreferences for drift seeding), seeds the local drift DB, and
/// starts the app inside a [ProviderScope]. The session restores
/// asynchronously from secure storage once the tree is up.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final prefs = await SharedPreferences.getInstance();

  // drift-backed local backend. Seed once (and on date rollover) so the
  // app boots with the Figma mock's client/schedule data before the
  // real backend exists. drift opens lazily — the first query
  // (`seedIfEmpty`) is what can throw (e.g. missing sqlite3 WASM on
  // web), so we log-and-continue: the UI still renders and reads an
  // empty DB.
  final db = AppDatabase();
  try {
    await seedIfEmpty(db);
  } catch (e) {
    debugPrint('Trainer drift seed failed — booting with no local data: $e');
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const OncareTrainerApp(),
    ),
  );
}
