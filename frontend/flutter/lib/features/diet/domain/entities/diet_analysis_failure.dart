import 'package:oncare/core/errors/app_error.dart';

/// Why `POST /diet/analyze` failed, in the terms the user needs.
///
/// The distinction that matters is **whether retrying the same photo can
/// ever succeed**. Telling someone to "잠시 후 다시 시도" when the server
/// rejected the image format sends them into a loop that always fails, so
/// each value below carries [canRetry] and the UI follows it.
///
/// Status codes come from `backend/app/api/v1/diet.py` — keep in sync.
enum DietAnalysisFailure {
  /// 415 — the server can't decode this image type.
  unsupportedFormat(canRetry: false),

  /// 400 — empty file, or a request the server refused to parse.
  badRequest(canRetry: false),

  /// 401 / 403 — the session is gone. There is no token refresh, so the
  /// user has to sign in again; retrying sends the same dead token.
  unauthorized(canRetry: false),

  /// 501 — no recognizer is wired up for this deployment.
  notImplemented(canRetry: false),

  /// 502 — the recognizer itself failed. Transient by nature.
  recognitionFailed(canRetry: true),

  /// Timeouts, connection drops, other 5xx — worth another attempt.
  temporary(canRetry: true);

  const DietAnalysisFailure({required this.canRetry});

  /// Whether re-sending the *same* photo has any chance of succeeding.
  final bool canRetry;

  /// Classifies whatever `analyze()` threw.
  ///
  /// Anything unrecognized becomes [temporary]: offering a retry on an
  /// unknown failure is the safer default — the request is idempotent by
  /// key, so a pointless retry costs nothing, while wrongly telling the
  /// user their photo is unusable would strand a perfectly good capture.
  factory DietAnalysisFailure.fromError(Object error) {
    if (error is! AppError) return DietAnalysisFailure.temporary;
    return switch (error) {
      UnauthorizedError() => DietAnalysisFailure.unauthorized,
      NetworkError() => DietAnalysisFailure.temporary,
      ServerError(:final int? statusCode) => switch (statusCode) {
        400 => DietAnalysisFailure.badRequest,
        415 => DietAnalysisFailure.unsupportedFormat,
        501 => DietAnalysisFailure.notImplemented,
        502 => DietAnalysisFailure.recognitionFailed,
        _ => DietAnalysisFailure.temporary,
      },
      _ => DietAnalysisFailure.temporary,
    };
  }
}
