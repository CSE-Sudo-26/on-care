import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';

/// Raised when a login attempt is rejected (empty credentials, invalid
/// credentials, or a network failure). Carries a Korean, user-facing
/// [message] ready to surface in a snackbar.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Raised when the authenticated account is not a trainer (the backend
/// answers `/trainer/me` with 403). The trainer app and the member app
/// use fully separate accounts, so a member credential must be rejected.
class NotTrainerException extends AuthException {
  const NotTrainerException([super.message = '트레이너 계정으로 로그인해 주세요.']);
}

/// Authenticates a trainer against the backend and reads the trainer
/// profile. Two implementations sit behind this contract:
///
///  * [MockTrainerAuthRepository] — demo / `USE_MOCK_API=true`;
///  * `DioTrainerAuthRepository` — the real FastAPI backend.
///
/// The UI depends only on this interface (never on Dio directly).
abstract class TrainerAuthRepository {
  /// Exchanges email/password for tokens (POST /v1/auth/login).
  /// Throws [AuthException] on failure.
  Future<TrainerAuthTokens> login({
    required String email,
    required String password,
  });

  /// Creates a new trainer account (POST /v1/auth/register) and returns
  /// tokens. Throws [AuthException] (e.g. 409 duplicate email).
  Future<TrainerAuthTokens> register({
    required String email,
    required String password,
    required String name,
  });

  /// Exchanges a provider (kakao/google) [token] for tokens
  /// (POST /v1/auth/social/{provider}). Throws [AuthException].
  Future<TrainerAuthTokens> socialLogin({
    required String provider,
    required String token,
  });

  /// Rotates an expired session (POST /v1/auth/refresh). Throws
  /// [AuthException] when the refresh token is invalid/expired.
  Future<TrainerAuthTokens> refresh(String refreshToken);

  /// Reads the signed-in trainer's profile (GET /v1/trainer/me) using
  /// [accessToken].
  ///
  /// Error contract (kept in sync with the Dio implementation so callers
  /// can catch precisely):
  ///  * 403 → [NotTrainerException] — the account is not a trainer;
  ///  * 401 → `UnauthorizedError` (from `core/errors`), surfaced so
  ///    `SessionController` can attempt a token refresh;
  ///  * transport / empty-body failures → a typed `AppError`
  ///    (`NetworkError` / `ServerError`), NOT [AuthException], so restore
  ///    treats a transient failure as recoverable and keeps the tokens.
  Future<TrainerProfile> fetchProfile(String accessToken);
}
