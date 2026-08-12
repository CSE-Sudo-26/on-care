import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deployment environment. Selected at build time via `--dart-define=ENV`.
enum Environment { dev, staging, prod }

/// App-wide configuration resolved from `--dart-define`s at build time.
///
/// Mirrors the user app (`frontend/flutter`) so both On-Care apps share
/// the same networking contract. The trainer web build (GitHub Pages)
/// passes `API_BASE_URL` + `USE_MOCK_API=false` to hit the real backend;
/// local/demo builds fall back to the mock repositories.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.useMockApi,
  });

  final Environment environment;

  /// Base URL of the FastAPI backend, including the `/v1` prefix.
  final String apiBaseUrl;

  /// When true, feature providers resolve to the in-memory / drift mock
  /// repositories instead of the Dio-backed ones. Used for the demo
  /// bypass and while running without a backend.
  final bool useMockApi;

  bool get isProd => environment == Environment.prod;

  factory AppConfig.fromEnvironment() {
    const envStr = String.fromEnvironment('ENV', defaultValue: 'dev');
    final env = switch (envStr) {
      'prod' => Environment.prod,
      'staging' => Environment.staging,
      _ => Environment.dev,
    };
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://dev.api.oncare.example.com/v1',
    );
    // Default to mock so `flutter run`/tests work with no backend; the
    // real web build opts in with USE_MOCK_API=false.
    const useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: true);
    return AppConfig(
      environment: env,
      apiBaseUrl: apiBaseUrl,
      useMockApi: useMockApi,
    );
  }
}

/// Overridden in [ProviderScope] at startup (see `bootstrap()`), resolved
/// from [AppConfig.fromEnvironment]. Reading it before the override throws.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap() before use.',
  );
}, name: 'appConfig');
