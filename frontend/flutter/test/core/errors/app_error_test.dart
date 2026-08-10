import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/errors/app_error.dart';

void main() {
  RequestOptions opts() => RequestOptions(path: '/ping');

  group('AppError.fromDio', () {
    test('timeouts → NetworkError', () {
      final e = AppError.fromDio(
        DioException(
          requestOptions: opts(),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(e, isA<NetworkError>());
    });

    test('cancel → CancelledError', () {
      final e = AppError.fromDio(
        DioException(requestOptions: opts(), type: DioExceptionType.cancel),
      );
      expect(e, isA<CancelledError>());
    });

    test('401 → UnauthorizedError', () {
      final e = AppError.fromDio(
        DioException(
          requestOptions: opts(),
          type: DioExceptionType.badResponse,
          response: Response<void>(requestOptions: opts(), statusCode: 401),
        ),
      );
      expect(e, isA<UnauthorizedError>());
    });

    test('404 → NotFoundError', () {
      final e = AppError.fromDio(
        DioException(
          requestOptions: opts(),
          type: DioExceptionType.badResponse,
          response: Response<void>(requestOptions: opts(), statusCode: 404),
        ),
      );
      expect(e, isA<NotFoundError>());
    });

    test('500 → ServerError carrying status code', () {
      final e = AppError.fromDio(
        DioException(
          requestOptions: opts(),
          type: DioExceptionType.badResponse,
          response: Response<void>(requestOptions: opts(), statusCode: 502),
        ),
      );
      expect(e, isA<ServerError>());
      expect((e as ServerError).statusCode, 502);
    });
  });

}
