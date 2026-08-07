import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Short-circuits known endpoints with canned data so the app can run
/// before the real REST backend exists. Toggle via
/// `--dart-define=USE_MOCK_API=false`.
class MockApiInterceptor extends Interceptor {
  MockApiInterceptor(this._logger, {this.isRealApiPath});
  final Logger _logger;

  /// 이 경로를 목업이 아니라 실 백엔드로 보내야 하는지 판정한다
  /// (`AppConfig.isRealApiPath`). LocalApiInterceptor 와 같은 규칙을 쓴다.
  final bool Function(String path)? isRealApiPath;

  // Path → JSON map. Add new mock endpoints here as features need them.
  static const Map<String, Map<String, Object?>> _routes =
      <String, Map<String, Object?>>{
        'GET /ping': <String, Object?>{'message': 'pong (mock)'},
        'GET /me': <String, Object?>{
          'id': 'demo-user',
          'name': 'Demo User',
          'locale': 'ko',
        },
      };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // REAL_API 로 켠 기능은 목업이 가로채지 않고 실 백엔드로 흘려보낸다.
    if (isRealApiPath != null && isRealApiPath!(options.path)) {
      handler.next(options);
      return;
    }
    final key = '${options.method.toUpperCase()} ${options.path}';
    final body = _routes[key];
    if (body == null) {
      handler.next(options);
      return;
    }
    _logger.d('[mock] $key -> 200');
    handler.resolve(
      Response<Map<String, Object?>>(
        requestOptions: options,
        statusCode: 200,
        data: body,
      ),
    );
  }
}
