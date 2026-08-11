/// 저장된 토큰으로 세션을 되살리는 경로 — #618.
///
/// 예전에는 토큰이 **있기만 하면** 인증 상태로 넘어갔다. 접근 토큰 수명이 하루라,
/// 다음 날 앱을 켜면 로그인된 화면이 뜨지만 모든 요청이 실패하고 수동 로그아웃 말고는
/// 빠져나갈 길이 없었다. 갱신 토큰은 저장만 하고 쓰지 않았다.
///
/// 여기서 고정하는 성질은 넷이다.
///
///  * 유효한지 확인하고 들어간다.
///  * 만료면 갱신 토큰으로 한 번 회전한다.
///  * 갱신까지 죽었으면 저장 토큰을 지우고 로그인 화면으로 보낸다.
///  * 네트워크가 잠깐 안 되는 것과 세션이 끝난 것을 구분한다 — 전자는 토큰을 지키다.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/app/session_feature_reset.dart';
import 'package:oncare/core/network/auth_token.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/core/storage/secure_token_store.dart';
import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';

/// 한 요청에 대한 답. 상태 코드나 예외 중 하나를 낸다.
class _Reply {
  const _Reply.ok(this.body) : status = 200, throwsConnection = false;
  const _Reply.status(this.status) : body = null, throwsConnection = false;
  const _Reply.connectionError()
    : status = 0,
      body = null,
      throwsConnection = true;

  final int status;
  final Map<String, Object?>? body;
  final bool throwsConnection;
}

/// `METHOD /path` → 순서대로 소비할 답 목록. 목록이 마르면 마지막 답을 반복한다.
class _ScriptedDio {
  _ScriptedDio(this._script);

  final Map<String, List<_Reply>> _script;

  /// 실제로 나간 요청 기록 — 어떤 토큰을 달고 갔는지까지 본다.
  final List<RequestOptions> requests = <RequestOptions>[];

  Dio build({Duration delay = Duration.zero}) {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
              requests.add(options);
              if (delay > Duration.zero) await Future<void>.delayed(delay);

              final String key = '${options.method.toUpperCase()} ${options.path}';
              final List<_Reply>? replies = _script[key];
              if (replies == null || replies.isEmpty) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response<Object?>(
                      requestOptions: options,
                      statusCode: 404,
                    ),
                  ),
                );
                return;
              }
              final _Reply reply = replies.length == 1
                  ? replies.first
                  : replies.removeAt(0);

              if (reply.throwsConnection) {
                handler.reject(
                  DioException.connectionError(
                    requestOptions: options,
                    reason: '연결 실패',
                  ),
                );
                return;
              }
              if (reply.status >= 400) {
                handler.reject(
                  DioException.badResponse(
                    statusCode: reply.status,
                    requestOptions: options,
                    response: Response<Object?>(
                      requestOptions: options,
                      statusCode: reply.status,
                    ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, Object?>>(
                  requestOptions: options,
                  statusCode: reply.status,
                  data: reply.body ?? <String, Object?>{},
                ),
              );
            },
      ),
    );
    return dio;
  }

  /// 이 요청이 달고 간 Bearer 토큰.
  String? bearerOf(int index) {
    final Object? header = requests[index].headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }
}

ProviderContainer _container(Dio dio) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      dioProvider.overrideWithValue(dio),
      sessionFeatureResetOverride(),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle(ProviderContainer container) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (container.read(sessionControllerProvider).status !=
        SessionStatus.unknown) {
      // 상태가 정해진 뒤에도 저장소 정리 같은 후속 작업이 남아 있을 수 있다.
      await Future<void>.delayed(Duration.zero);
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('세션 상태가 정해지지 않았다');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'access_token': 'stored-access',
      'refresh_token': 'stored-refresh',
    });
  });

  test('저장된 토큰이 유효하면 확인하고 들어간다', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[const _Reply.ok(<String, Object?>{'id': 'u1'})],
    });
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.authenticated,
    );
    // 저장된 토큰이 그대로 세션에 올라간다.
    expect(container.read(authAccessTokenProvider), 'stored-access');
    // 확인 요청은 저장된 토큰을 달고 나간다 — 세션에 넣기 전에 찔러 봐야 한다.
    expect(script.bearerOf(0), 'stored-access');
  });

  test('토큰이 없으면 확인하지 않고 로그인 화면으로', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final script = _ScriptedDio(<String, List<_Reply>>{});
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.signedOut,
    );
    // 확인할 것이 없으므로 네트워크로 나가지 않는다.
    expect(script.requests, isEmpty);
  });

  test('만료된 접근 토큰은 갱신 토큰으로 한 번 회전한다', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[
        const _Reply.status(401),
        const _Reply.ok(<String, Object?>{'id': 'u1'}),
      ],
      'POST /auth/refresh': <_Reply>[
        const _Reply.ok(<String, Object?>{
          'access_token': 'rotated-access',
          'refresh_token': 'rotated-refresh',
        }),
      ],
    });
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.authenticated,
    );
    expect(container.read(authAccessTokenProvider), 'rotated-access');
    // 두 번째 확인은 회전한 토큰으로 나간다.
    expect(script.bearerOf(2), 'rotated-access');
    // 회전 결과가 저장돼야 다음 실행에서도 되살아난다.
    final store = container.read(secureTokenStoreProvider);
    expect(await store.readAccessToken(), 'rotated-access');
    expect(await store.readRefreshToken(), 'rotated-refresh');
  });

  test('갱신 토큰을 새로 주지 않으면 쓰던 것을 유지한다', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[
        const _Reply.status(401),
        const _Reply.ok(<String, Object?>{'id': 'u1'}),
      ],
      'POST /auth/refresh': <_Reply>[
        // 접근 토큰만 회전시키는 서버. 갱신 토큰을 지워 버리면 다음 만료 때 되살릴
        // 방법이 없어진다.
        const _Reply.ok(<String, Object?>{'access_token': 'rotated-access'}),
      ],
    });
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.authenticated,
    );
    final store = container.read(secureTokenStoreProvider);
    expect(await store.readRefreshToken(), 'stored-refresh');
  });

  test('갱신까지 거부되면 저장 토큰을 지우고 로그인 화면으로', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[const _Reply.status(401)],
      'POST /auth/refresh': <_Reply>[const _Reply.status(401)],
    });
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.signedOut,
    );
    expect(container.read(authAccessTokenProvider), isNull);
    // 죽은 토큰을 남겨 두면 다음 실행에서도 같은 실패를 반복한다.
    final store = container.read(secureTokenStoreProvider);
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });

  test('회전한 토큰마저 거부되면 다시 갱신하지 않는다', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[const _Reply.status(401)],
      'POST /auth/refresh': <_Reply>[
        const _Reply.ok(<String, Object?>{'access_token': 'rotated-access'}),
      ],
    });
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.signedOut,
    );
    // 갱신은 한 번만 — 무한 회전에 빠지면 앱이 켜지지 않는다.
    final int refreshCalls = script.requests
        .where((RequestOptions r) => r.path == '/auth/refresh')
        .length;
    expect(refreshCalls, 1);
  });

  test('네트워크가 안 되면 로그아웃 상태로 두되 토큰은 지키다', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[const _Reply.connectionError()],
    });
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.signedOut,
    );
    // 지하철에서 앱을 켰다고 세션을 잃으면 안 된다 — 다음 실행에서 되살아나야 한다.
    final store = container.read(secureTokenStoreProvider);
    expect(await store.readAccessToken(), 'stored-access');
    expect(await store.readRefreshToken(), 'stored-refresh');
  });

  test('서버 오류도 세션 만료로 보지 않는다', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[const _Reply.status(500)],
    });
    final container = _container(script.build());

    container.read(sessionControllerProvider.notifier);
    await _settle(container);

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.signedOut,
    );
    final store = container.read(secureTokenStoreProvider);
    expect(await store.readAccessToken(), 'stored-access');
  });

  test('복구 중 사용자가 데모로 들어가면 복구가 그것을 덮지 않는다', () async {
    final script = _ScriptedDio(<String, List<_Reply>>{
      'GET /users/me': <_Reply>[const _Reply.ok(<String, Object?>{'id': 'u1'})],
    });
    // 복구가 아직 끝나지 않은 사이에 사용자가 버튼을 누르는 상황.
    final container = _container(
      script.build(delay: const Duration(milliseconds: 50)),
    );

    final SessionController controller = container.read(
      sessionControllerProvider.notifier,
    );
    controller.enterDemo();
    // 복구가 끝나고도 남을 만큼 기다린다.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.demo,
    );
    // 데모는 토큰 없이 도는 경로다.
    expect(container.read(authAccessTokenProvider), isNull);
  });
}
