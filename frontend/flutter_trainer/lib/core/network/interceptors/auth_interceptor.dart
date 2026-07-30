import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/network/auth_token.dart';

/// Attaches `Authorization: Bearer <token>` to outgoing requests when a
/// session token is present and the caller has not already set one
/// (login → `/trainer/me` passes an explicit header before the token is
/// mirrored into [authAccessTokenProvider]). In mock mode no real
/// requests are made, so the header only matters against the live
/// FastAPI backend.
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
