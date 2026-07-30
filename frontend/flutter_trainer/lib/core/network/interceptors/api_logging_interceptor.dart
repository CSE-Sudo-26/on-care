import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// One-line request/response/error logger, enabled outside prod via
/// `dioProvider`. Uses `debugPrint` to avoid pulling in a logging
/// package — the trainer app only needs coarse request tracing.
class ApiLoggingInterceptor extends Interceptor {
  const ApiLoggingInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[api>] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint(
      '[api<] ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[api!] ${err.type} ${err.requestOptions.uri} :: ${err.message}',
    );
    handler.next(err);
  }
}
