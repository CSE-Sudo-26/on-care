import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:oncare/app/app.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/core/logging/logging_provider_observer.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/storage/prefs_store.dart';
import 'package:oncare/core/storage/seed_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single entry point used by `main.dart`. Initializes binding,
/// resolves [AppConfig] from `--dart-define`s, awaits platform-async
/// services we want available synchronously to the widget tree
/// (SharedPreferences), installs a top-level error handler, and starts
/// the app inside a [ProviderScope].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final logger = Logger(level: config.isProd ? Level.info : Level.debug);
  logger.i(
    'oncare boot env=${config.environment.name} api=${config.apiBaseUrl}',
  );

  final prefs = await SharedPreferences.getInstance();

  // Local backend (drift-backed mock). Seed once on first run so the
  // app boots with the React prototype's mock data even before the
  // real FastAPI server exists. See docs/DUMMY_BACKEND.md.
  //
  // The drift open is lazy — the first query (the `seedIfEmpty`
  // below) is what can throw. On the web build, drift needs
  // `sqlite3.wasm` + `drift_worker.js` at the same origin; the
  // deploy workflow downloads them into `web/` from the drift
  // release matching `pubspec.lock`. If the fetch still fails (or
  // the browser lacks the storage APIs drift needs), we log and
  // continue — the UI renders, individual feature pages will show
  // their own error states when they hit the empty DB.
  final db = AppDatabase();
  try {
    await seedIfEmpty(db);
  } catch (e, st) {
    logger.e(
      'Drift seed failed — app will boot with no local data',
      error: e,
      stackTrace: st,
    );
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.e(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
        logger.e('Uncaught platform error', error: error, stackTrace: stack);
        return true;
      };

  // Provider observers — log lifecycle events outside prod.
  final observers = <ProviderObserver>[
    if (!config.isProd) LoggingProviderObserver(logger),
  ];

  runApp(
    ProviderScope(
      observers: observers,
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
        appLoggerProvider.overrideWithValue(logger),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const OncareApp(),
    ),
  );
}
