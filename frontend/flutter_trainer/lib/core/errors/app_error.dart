import 'package:dio/dio.dart';

/// Domain-level error type for the whole app. Repositories convert any
/// transport / framework exception into one of these before surfacing it
/// to controllers, so UI code never has to type-test `DioException`
/// directly. Mirrors the user app (`frontend/flutter`).
sealed class AppError implements Exception {
  const AppError({this.message, this.cause, this.stackTrace});

  final String? message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType(message: $message)';

  /// Map a `DioException` into the closest AppError. Add new branches
  /// here rather than at call sites.
  factory AppError.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return NetworkError(
          message: e.message,
          cause: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.cancel:
        return const CancelledError();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 401) {
          return UnauthorizedError(message: e.message);
        }
        if (code == 403) {
          return ForbiddenError(message: e.message);
        }
        if (code == 404) {
          return NotFoundError(message: e.message);
        }
        return ServerError(statusCode: code, message: e.message);
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return UnknownError(
          message: e.message,
          cause: e,
          stackTrace: e.stackTrace,
        );
    }
  }
}

class NetworkError extends AppError {
  const NetworkError({super.message, super.cause, super.stackTrace});
}

/// 401 — missing / expired / invalid credentials. Triggers a refresh or
/// session expiry.
class UnauthorizedError extends AppError {
  const UnauthorizedError({super.message});
}

/// 403 — authenticated but not allowed (e.g. a member account hitting a
/// `/trainer/*` endpoint).
class ForbiddenError extends AppError {
  const ForbiddenError({super.message});
}

class NotFoundError extends AppError {
  const NotFoundError({super.message});
}

class ServerError extends AppError {
  const ServerError({this.statusCode, super.message});
  final int? statusCode;

  @override
  String toString() => 'ServerError(status: $statusCode, message: $message)';
}

class CancelledError extends AppError {
  const CancelledError();
}

class UnknownError extends AppError {
  const UnknownError({super.message, super.cause, super.stackTrace});
}
