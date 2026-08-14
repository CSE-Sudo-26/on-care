import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 로그인·가입 실패의 **원인 코드**. 문구가 아니다.
///
/// 리포지토리에는 컨텍스트가 없어 로케일을 알 수 없다. 여기서 한국어 문장을
/// 들고 있으면 영어 로케일에서 그 문장만 한국어로 남는다. 화면이 코드를 받아
/// 자기 언어의 문구를 붙인다. (#501)
enum AuthFailure {
  invalidCredentials,
  emailTaken,
  inviteCodeInvalid,
  sessionExpired,
  noSocialToken,
  emptyCredentials,
  network,
  emptyResponse,
  notTrainer,
  unknown,
}

/// 로그인·가입이 거부됐을 때 던진다. 사용자에게 보일 문구가 아니라
/// [AuthFailure] 코드를 들고 나가며, 문구는 화면이 [authFailureText] 로 붙인다.
class AuthException implements Exception {
  const AuthException(this.failure, {this.detail});

  /// 무엇이 잘못됐는가. 화면이 이 값으로 문구를 고른다.
  final AuthFailure failure;

  /// 로그·디버깅용 상세(파서 메시지 등). **화면에 그리지 않는다** — 로케일도
  /// 모르고 사용자가 읽을 문장도 아니다. [toString] 에만 실린다.
  final String? detail;

  @override
  String toString() =>
      'AuthException: $failure${detail == null ? '' : ' ($detail)'}';
}

/// Raised when the authenticated account is not a trainer (the backend
/// answers `/trainer/me` with 403). The trainer app and the member app
/// use fully separate accounts, so a member credential must be rejected.
class NotTrainerException extends AuthException {
  const NotTrainerException() : super(AuthFailure.notTrainer);
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

  /// Creates a new trainer account (POST /v1/auth/trainer/register) and
  /// returns tokens. Throws [AuthException] (409 duplicate email, 422
  /// unusable invite code).
  ///
  /// [inviteCode] is the gym's invite code and is **required**: it decides
  /// which gym the new trainer belongs to. A trainer with no gym cannot be
  /// a consultation target, so signing up without one would land the
  /// account in a state where nothing works. (#475)
  Future<TrainerAuthTokens> register({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
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

/// 실패 코드 → 현재 로케일의 문구. (#501)
///
/// [AuthException.detail] 은 쓰지 않는다. 지금 그 자리에 들어오는 값은 서버가 준
/// 사유가 아니라 토큰 파싱 실패의 [FormatException] 메시지뿐이라, 그대로 내보내면
/// 로케일과 무관하게 파서 내부 문구가 사용자에게 보인다.
String authFailureText(AppLocalizations l, AuthException e) {
  return switch (e.failure) {
    AuthFailure.invalidCredentials => l.authErrInvalidCredentials,
    AuthFailure.emailTaken => l.authErrEmailTaken,
    AuthFailure.inviteCodeInvalid => l.authErrInviteCodeInvalid,
    AuthFailure.sessionExpired => l.authErrSessionExpired,
    AuthFailure.noSocialToken => l.authErrNoSocialToken,
    AuthFailure.emptyCredentials => l.authErrEmptyCredentials,
    AuthFailure.network => l.authErrNetwork,
    AuthFailure.emptyResponse => l.authErrEmptyResponse,
    AuthFailure.notTrainer => l.authErrNotTrainer,
    AuthFailure.unknown => l.authErrGeneric,
  };
}
