/// 기능별 실 백엔드 전환 스위치(`REAL_API`) — #457.
///
/// `USE_MOCK_API` 는 전역이라 끄는 순간 로그인·홈·식단·운동·채팅이 한꺼번에 실서버로
/// 넘어간다. 이 스위치는 준비된 기능만 골라 실연동할 수 있게 한다.
///
/// **가장 중요한 계약은 "키를 주지 않으면 지금과 완전히 같다"**이다. 배포된 데모가
/// 조용히 실서버를 치기 시작하면 안 된다.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/interceptors/mock_api_interceptor.dart';

AppConfig _config({Set<String> realApi = const <String>{}}) => AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://example.test/v1',
  useMockApi: true,
  realApiFeatures: realApi,
);

void main() {
  group('AppConfig.isRealApiPath', () {
    test('키를 주지 않으면 어떤 경로도 실 백엔드로 가지 않는다', () {
      final AppConfig config = _config();

      // 데모 배포가 이 경로다 — 하나라도 true 면 조용히 실서버를 치기 시작한다.
      for (final String path in <String>[
        '/ai-coach/chat',
        '/ai-coach/messages',
        '/auth/login',
        '/auth/social/kakao',
        '/diet/days/today',
        '/dashboard/summary',
      ]) {
        expect(config.isRealApiPath(path), isFalse, reason: path);
      }
    });

    test('켠 기능의 경로만 실 백엔드로 간다', () {
      final AppConfig config = _config(realApi: <String>{'ai-coach'});

      expect(config.isRealApiPath('/ai-coach/chat'), isTrue);
      expect(config.isRealApiPath('/ai-coach/messages'), isTrue);
      // 켜지 않은 기능은 그대로 목업
      expect(config.isRealApiPath('/auth/login'), isFalse);
      expect(config.isRealApiPath('/diet/days/today'), isFalse);
      expect(config.isRealApiPath('/dashboard/summary'), isFalse);
    });

    test('여러 기능을 함께 켤 수 있다', () {
      final AppConfig config = _config(realApi: <String>{'ai-coach', 'auth'});

      expect(config.isRealApiPath('/ai-coach/chat'), isTrue);
      expect(config.isRealApiPath('/auth/social/google'), isTrue);
      expect(config.isRealApiPath('/diet/days/today'), isFalse);
    });

    test('알 수 없는 키는 아무 경로도 열지 않는다', () {
      // 오타가 조용히 전 기능을 실서버로 보내면 최악이다.
      final AppConfig config = _config(realApi: <String>{'ai_coach', 'typo'});

      expect(config.isRealApiPath('/ai-coach/chat'), isFalse);
      expect(config.isRealApiPath('/auth/login'), isFalse);
    });

    test('등록된 기능 키는 모두 경로가 정의돼 있다', () {
      for (final MapEntry<String, List<String>> entry
          in kRealApiFeatures.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} 에 경로가 없다');
        for (final String prefix in entry.value) {
          expect(prefix.startsWith('/'), isTrue, reason: prefix);
        }
      }
    });
  });

  group('MockApiInterceptor', () {
    late Logger logger;

    setUp(() => logger = Logger(level: Level.off));

    /// 인터셉터가 목업 응답으로 가로챘는지(resolve), 흘려보냈는지(next) 판정.
    Future<bool> intercepted(
      MockApiInterceptor interceptor,
      String path,
    ) async {
      final options = RequestOptions(path: path, method: 'GET');
      bool resolved = false;
      final handler = _RecordingHandler(onResolve: () => resolved = true);
      interceptor.onRequest(options, handler);
      return resolved;
    }

    test('스위치가 꺼져 있으면 알려진 경로를 그대로 가로챈다', () async {
      final interceptor = MockApiInterceptor(logger);
      expect(await intercepted(interceptor, '/ping'), isTrue);
    });

    test('스위치가 켜진 경로는 가로채지 않고 흘려보낸다', () async {
      final interceptor = MockApiInterceptor(
        logger,
        isRealApiPath: (String path) => path.startsWith('/ping'),
      );
      expect(await intercepted(interceptor, '/ping'), isFalse);
    });
  });
}

/// resolve/next 중 무엇이 불렸는지만 기록하는 핸들러.
class _RecordingHandler extends RequestInterceptorHandler {
  _RecordingHandler({required this.onResolve});

  final void Function() onResolve;

  @override
  void resolve(Response<dynamic> response, [bool callFollowingResponseInterceptor = false]) {
    onResolve();
  }

  @override
  void next(RequestOptions requestOptions) {}
}
