/// Raised when a login attempt is rejected (e.g. empty credentials, or
/// invalid credentials once the real backend validates them).
class AuthException implements Exception {
  /// Creates an auth failure with a user-facing [message].
  const AuthException(this.message);

  /// Human-readable, Korean, ready to surface in a snackbar.
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Authenticates a trainer and returns a session access token.
///
/// Defined fresh for the trainer app — the user app's auth repository
/// is not reused. The real implementation (POST /auth/login) replaces
/// [MockTrainerAuthRepository] when the backend lands, keeping this
/// contract.
abstract class TrainerAuthRepository {
  /// Exchanges email/password for an access token. Throws
  /// [AuthException] on failure.
  Future<String> login({required String email, required String password});

  /// Creates a new trainer account (POST /auth/register) and returns an
  /// access token. Distinct from [login] so the real backend can enforce
  /// account-creation semantics and persist [name]. Throws [AuthException].
  Future<String> register({
    required String email,
    required String password,
    required String name,
  });

  /// Exchanges a provider (kakao/google) [token] for an access token
  /// (POST /auth/social). The real backend validates the provider token;
  /// the mock issues a demo token. Throws [AuthException].
  Future<String> socialLogin({
    required String provider,
    required String token,
  });
}
