/// A pair of JWT tokens issued by the backend auth endpoints.
///
/// The access token authorizes API calls; the refresh token mints a new
/// pair when the access token expires (POST /v1/auth/refresh).
class TrainerAuthTokens {
  const TrainerAuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  /// Parses `{ access_token, refresh_token }` (snake_case, per the
  /// FastAPI `Token` schema). Throws [FormatException] if no access token
  /// is present so callers fail loudly rather than storing an empty token.
  factory TrainerAuthTokens.fromJson(Map<String, Object?> json) {
    final access = (json['access_token'] as String?) ?? '';
    if (access.isEmpty) {
      throw const FormatException('응답에 access_token 이 없습니다.');
    }
    return TrainerAuthTokens(
      access: access,
      refresh: (json['refresh_token'] as String?) ?? '',
    );
  }
}
