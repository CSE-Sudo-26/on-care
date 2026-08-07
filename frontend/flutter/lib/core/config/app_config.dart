import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Environment { dev, staging, prod }

/// `REAL_API` 로 켤 수 있는 기능 키 → 실 백엔드로 보낼 경로 접두사.
///
/// 목업 인터셉터가 가로채는 경로 중 **어디까지를 실 서버로 넘길지**를 여기 한 곳에서
/// 정한다. 기능별로 임시 플래그(`REAL_AI_COACH`, `REAL_AUTH` …)를 각각 만들면
/// `AppConfig` 와 인터셉터라는 같은 파일이 이슈마다 고쳐져 충돌하므로, 키 목록을 받는
/// 스위치 하나로 통일한다.
///
/// 새 기능을 켤 수 있게 하려면 여기에 키와 경로만 추가하면 된다 — 인터셉터는 손대지
/// 않는다.
const Map<String, List<String>> kRealApiFeatures = <String, List<String>>{
  // AI 코치(온이) 대화·피드백. 리포지토리를 교체하지 않고 인터셉터만 가로채는
  // 구조라, 경로만 흘려보내면 곧바로 실 Gemini 응답이 된다.
  'ai-coach': <String>['/ai-coach'],
  // 소셜 로그인 포함 인증. 실 OAuth 토큰을 서버가 검증하게 하려면 필요하다.
  'auth': <String>['/auth'],
  // 식단 기록·분석·추천.
  'diet': <String>['/diet'],
};

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.useMockApi,
    this.sentryDsn,
    this.realApiFeatures = const <String>{},
  });

  final Environment environment;
  final String apiBaseUrl;
  final String? sentryDsn;

  /// When true, [MockApiInterceptor] short-circuits any HTTP request
  /// matching a known path and returns canned data. Used while the
  /// real REST backend (Q1 decision) is being built.
  final bool useMockApi;

  /// 목업 모드에서도 **실 백엔드를 쓸 기능 키** 목록.
  ///
  /// `useMockApi` 는 전역 스위치라 끄는 순간 로그인·홈·식단·운동·채팅이 한꺼번에
  /// 실서버로 넘어간다. 그래서 준비된 기능 하나만 먼저 실연동해 보여줄 수가 없었다.
  /// 이 목록에 든 키에 해당하는 경로는 목업 인터셉터가 가로채지 않고 실 네트워크로
  /// 흘려보낸다.
  ///
  /// 비어 있으면(기본값) 지금까지의 데모 동작과 **완전히 동일**하다.
  ///
  /// 키 → 경로 대응은 [kRealApiFeatures] 참고.
  /// 예: `--dart-define=REAL_API=ai-coach,auth`
  final Set<String> realApiFeatures;

  /// 이 경로를 목업이 아니라 실 백엔드로 보내야 하는가.
  bool isRealApiPath(String path) {
    if (realApiFeatures.isEmpty) return false;
    for (final String feature in realApiFeatures) {
      final List<String> prefixes = kRealApiFeatures[feature] ?? const <String>[];
      for (final String prefix in prefixes) {
        if (path.startsWith(prefix)) return true;
      }
    }
    return false;
  }

  bool get isProd => environment == Environment.prod;
  bool get isDev => environment == Environment.dev;

  factory AppConfig.fromEnvironment() {
    const envStr = String.fromEnvironment('ENV', defaultValue: 'dev');
    final env = switch (envStr) {
      'prod' => Environment.prod,
      'staging' => Environment.staging,
      _ => Environment.dev,
    };
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://dev.api.oncare.example.com',
    );
    const sentryDsn = String.fromEnvironment('SENTRY_DSN');
    const useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: true);
    // 예: --dart-define=REAL_API=ai-coach,auth
    // 알 수 없는 키는 무시된다(오타가 조용히 전 기능을 실서버로 보내지 않도록,
    // 매칭되는 경로가 없으면 아무 일도 일어나지 않는다).
    const realApi = String.fromEnvironment('REAL_API');
    return AppConfig(
      environment: env,
      apiBaseUrl: apiBaseUrl,
      sentryDsn: sentryDsn.isEmpty ? null : sentryDsn,
      useMockApi: useMockApi,
      realApiFeatures: <String>{
        for (final String key in realApi.split(','))
          if (key.trim().isNotEmpty) key.trim(),
      },
    );
  }
}

/// Override in [ProviderScope] at app startup with the value resolved
/// from [AppConfig.fromEnvironment]. Reading it before override throws.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in ProviderScope before use.',
  );
});
