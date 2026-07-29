import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/storage/session_token_store.dart';
import 'package:oncare_trainer/features/auth/data/repositories/mock_trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';

/// Owns the trainer session lifecycle: restore-on-launch, mock login,
/// demo bypass, and sign-out.
///
/// Designed fresh for the trainer app (the user app's SessionController
/// is not reused — it has no trainer-account concept). On a successful
/// login the single fixed [seedTrainerProfile] is attached to the
/// session; the persisted token lets the session survive an app
/// restart.
class SessionController extends StateNotifier<SessionState> {
  /// Creates the controller and kicks off session restore.
  SessionController(this._authRepository, this._tokenStore)
    : super(const SessionState()) {
    _restore();
  }

  final TrainerAuthRepository _authRepository;
  final SessionTokenStore _tokenStore;

  /// Resolves the initial session from persisted state. A stored token
  /// means the trainer stays logged in; the profile identity submitted at
  /// 회원가입 (name/email) is restored from persistence so a restart keeps
  /// the registered account instead of reverting to the seed. Otherwise
  /// they land signed out. Demo mode is never persisted.
  void _restore() {
    final token = _tokenStore.readToken();
    if (token != null) {
      state = SessionState(
        status: SessionStatus.authenticated,
        // 저장된 이름/이메일이 있으면 복원(가입 세션), 없으면 시드 유지(로그인 세션).
        profile: seedTrainerProfile.copyWith(
          name: _tokenStore.readProfileName(),
          email: _tokenStore.readProfileEmail(),
        ),
      );
    } else {
      state = const SessionState(status: SessionStatus.signedOut);
    }
  }

  /// Logs in with email/password (mock: any non-empty credentials
  /// succeed). Persists the token and attaches the seed profile.
  /// Throws [AuthException] on failure.
  Future<void> login({required String email, required String password}) async {
    final token = await _authRepository.login(email: email, password: password);
    // 로그인은 시드 정체성 — 저장된 가입 이름/이메일이 있으면 지워 시드로 복원되게 한다.
    await _tokenStore.saveSession(token: token);
    state = const SessionState(
      status: SessionStatus.authenticated,
      profile: seedTrainerProfile,
    );
  }

  /// 회원가입 — creates an account and signs in. Mock: reuses the login
  /// exchange (any non-empty credentials succeed) and attaches the seed
  /// profile. The real backend (POST /auth/register) replaces this later.
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final token = await _authRepository.register(
      email: email,
      password: password,
      name: name,
    );
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    // 데모: 제출한 이름/이메일을 토큰과 함께 영속화해 앱 재시작 후에도 가입 정체성이
    // 시드 계정으로 되돌아가지 않게 한다(빈 값이면 저장하지 않아 시드 값 유지).
    await _tokenStore.saveSession(
      token: token,
      name: trimmedName.isEmpty ? null : trimmedName,
      email: trimmedEmail.isEmpty ? null : trimmedEmail,
    );
    state = SessionState(
      status: SessionStatus.authenticated,
      profile: seedTrainerProfile.copyWith(
        name: trimmedName.isEmpty ? null : trimmedName,
        email: trimmedEmail.isEmpty ? null : trimmedEmail,
      ),
    );
  }

  /// Social sign-in (kakao / google). Mirrors the user app: until the
  /// real provider SDK lands, this exchanges a demo credential through the
  /// mock repo, persists the token, and attaches the seed profile.
  Future<void> socialLogin({required String provider}) async {
    // 사용자 앱과 동일: 실기기 SDK 연동 전까지 데모 토큰을 보내고, 실서버가
    // provider 토큰을 검증한다(트레이너 auth는 아직 전부 mock).
    final token = await _authRepository.socialLogin(
      provider: provider,
      token: 'demo-$provider-token',
    );
    // 소셜 로그인도 시드 정체성 — 저장된 가입 이름/이메일이 있으면 지운다.
    await _tokenStore.saveSession(token: token);
    state = const SessionState(
      status: SessionStatus.authenticated,
      profile: seedTrainerProfile,
    );
  }

  /// Enters demo mode — skip login, no token, browse with mock data.
  /// Not persisted, so a restart returns to the signed-out state.
  void enterDemo() {
    state = const SessionState(status: SessionStatus.demo);
  }

  /// Signs out — clears the persisted token and returns to the login
  /// screen.
  Future<void> signOut() async {
    await _tokenStore.clear();
    state = const SessionState(status: SessionStatus.signedOut);
  }
}

/// Exposes the trainer session state + controller app-wide.
final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      return SessionController(
        ref.watch(trainerAuthRepositoryProvider),
        ref.watch(sessionTokenStoreProvider),
      );
    }, name: 'trainerSession');
