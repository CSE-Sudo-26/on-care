import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/auth_token.dart';

/// Attaches `Authorization: Bearer <token>` to outgoing requests when a
/// session token is present **and the caller has not already set one**.
/// In mock mode the LocalApiInterceptor resolves requests before this runs,
/// so the token only matters against the real FastAPI backend
/// (USE_MOCK_API=false).
///
/// 호출부가 이미 넣은 헤더를 덮지 않는 이유: 세션 복구는 아직 세션에 반영하지 않은
/// 토큰으로 `GET /users/me` 를 찔러 본다. 그 토큰이 유효한지 확인하기 전에 세션에
/// 넣어 버리면, 만료된 토큰으로 앱이 잠시 로그인 상태가 된다. 트레이너 웹의 같은
/// 인터셉터도 같은 이유로 이렇게 동작한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.headers.containsKey('Authorization')) {
      final token = _ref.read(authAccessTokenProvider);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}
