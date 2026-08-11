import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/auth_token.dart';
import 'package:oncare_trainer/core/storage/secure_token_store.dart';
import 'package:oncare_trainer/features/auth/data/repositories/dio_trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';

/// Owns the trainer session lifecycle: restore-on-launch (with token
/// refresh), login / register / social login, demo bypass, and sign-out.
///
/// Real credentials now: login exchanges email/password for JWT tokens,
/// the profile comes from `GET /v1/trainer/me`, and a non-trainer account
/// is rejected (the trainer and member apps use separate accounts). In
/// `USE_MOCK_API=true` / demo mode the same flow runs against the
/// in-memory mock repository.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionState()) {
    _restore();
  }

  final Ref _ref;

  /// Set once the user drives an explicit auth action (login / register /
  /// social / demo / sign-out). The launch-time [_restore] is async, so on
  /// a slow real-backend `/me` the login screen (shown during
  /// [SessionStatus.unknown]) is interactive while restore is still in
  /// flight — this flag stops a late-resolving restore from clobbering the
  /// state the user just chose.
  bool _userActionStarted = false;

  /// Secure-storage mutations must finish in invocation order. In particular,
  /// a sign-out that starts while a refresh token save is in flight must clear
  /// after that save, otherwise the stale refresh can resurrect credentials.
  Future<void> _tokenStorageTail = Future<void>.value();

  TrainerAuthRepository get _repo => _ref.read(trainerAuthRepositoryProvider);
  SecureTokenStore get _tokens => _ref.read(secureTokenStoreProvider);

  void _setAccessToken(String? token) {
    _ref.read(authAccessTokenProvider.notifier).state = token;
  }

  // --- restore ------------------------------------------------------------

  /// Resolves the initial session from persisted tokens. A valid token
  /// (optionally after a refresh) plus a trainer `/me` lands authenticated;
  /// anything else lands signed out. Demo mode is never persisted.
  Future<void> _restore() async {
    // Read the two tokens independently: a refresh-token read failure must
    // not discard an access token that read back fine (review).
    String? access;
    String? refresh;
    try {
      access = await _tokens.readAccessToken();
    } catch (_) {
      access = null; // secure storage unavailable → treat as signed out
    }
    try {
      refresh = await _tokens.readRefreshToken();
    } catch (_) {
      refresh = null; // no refresh available; access alone can still restore
    }
    if (!mounted || _userActionStarted) return;
    if (access == null || access.isEmpty) {
      state = const SessionState(status: SessionStatus.signedOut);
      return;
    }
    await _resolveSession(
      access: access,
      refresh: refresh ?? '',
      allowRefresh: true,
    );
  }

  /// Attempts to authenticate with [access]; on 401 rotates once with
  /// [refresh]. Auth/role failures clear the session; transient failures
  /// (network/server) sign out without discarding the stored tokens so a
  /// later relaunch can retry.
  Future<void> _resolveSession({
    required String access,
    required String refresh,
    required bool allowRefresh,
  }) async {
    if (_userActionStarted) return;
    _setAccessToken(access);
    try {
      final profile = await _repo.fetchProfile(access);
      if (!mounted || _userActionStarted) return;
      state = SessionState(
        status: SessionStatus.authenticated,
        profile: profile,
      );
    } on NotTrainerException {
      if (_userActionStarted) return;
      await _expire();
    } on UnauthorizedError {
      if (_userActionStarted) return;
      if (allowRefresh && refresh.isNotEmpty) {
        await _refreshAndResolve(refresh);
      } else {
        await _expire();
      }
    } on AuthException catch (e) {
      if (_userActionStarted) return;
      // 인증 계열 실패라도 **명시적으로 거부된 것만** 세션의 끝이다. 같은 예외로
      // 실려 오는 연결 실패·서버 오류를 만료로 처리하면, 잠깐 끊긴 사용자에게
      // 재로그인을 요구하게 된다.
      if (_endsSession(e.failure)) {
        await _expire();
      } else {
        _keepTokensAndSignOut();
      }
    } catch (_) {
      // Transient (network/server) — keep tokens, just show signed out.
      if (!mounted || _userActionStarted) return;
      _keepTokensAndSignOut();
    }
  }

  /// 이 실패가 **세션의 끝**인가.
  ///
  /// 서버가 자격을 거부한 것(만료·잘못된 자격·트레이너 아님)만 해당한다. 연결 실패나
  /// 계약이 깨진 응답은 다음 실행에서 다시 시도할 여지가 있으므로 토큰을 남긴다.
  bool _endsSession(AuthFailure failure) => switch (failure) {
    AuthFailure.sessionExpired ||
    AuthFailure.invalidCredentials ||
    AuthFailure.notTrainer => true,
    AuthFailure.network ||
    AuthFailure.emptyResponse ||
    AuthFailure.unknown ||
    AuthFailure.emailTaken ||
    AuthFailure.inviteCodeInvalid ||
    AuthFailure.noSocialToken ||
    AuthFailure.emptyCredentials => false,
  };

  /// 이번에는 못 들어갔지만 세션이 끝난 것은 아니다 — 저장된 토큰을 남긴 채 로그인
  /// 화면으로 보낸다. 다음 실행에서 다시 시도한다.
  void _keepTokensAndSignOut() {
    if (!mounted || _userActionStarted) return;
    _setAccessToken(null);
    state = const SessionState(status: SessionStatus.signedOut);
  }

  Future<void> _refreshAndResolve(String refresh) async {
    if (_userActionStarted) return;
    final TrainerAuthTokens tokens;
    try {
      tokens = await _repo.refresh(refresh);
    } on AuthException catch (e) {
      // The refresh failed — but a user action (login/demo/sign-out) may
      // have landed during the slow call; don't clobber it.
      if (_userActionStarted) return;
      // 확인 요청과 같은 기준을 쓴다. 예전에는 여기서 모든 실패를 만료로 보내,
      // 갱신이 연결 실패나 서버 오류로 끝나도 저장된 토큰을 지웠다.
      if (_endsSession(e.failure)) {
        await _expire();
      } else {
        _keepTokensAndSignOut();
      }
      return;
    } catch (_) {
      if (_userActionStarted) return;
      _keepTokensAndSignOut();
      return;
    }
    // Re-check the race guard after the await, like every _resolveSession
    // branch does — a user action during a slow refresh must win.
    if (_userActionStarted) return;
    // Some backends rotate only the access token and omit a new refresh
    // token — keep the existing one then, or the next expiry can never
    // restore. An empty access is still a failure (fromJson guards it), so
    // only the refresh needs the fallback.
    final rotated = TrainerAuthTokens(
      access: tokens.access,
      refresh: tokens.refresh.isEmpty ? refresh : tokens.refresh,
    );
    await _persist(rotated);
    // A login/demo/sign-out may have started while secure storage was saving.
    // Its queued storage mutation runs after this stale save and must win.
    if (_userActionStarted) return;
    await _resolveSession(
      access: rotated.access,
      refresh: rotated.refresh,
      allowRefresh: false,
    );
  }

  // --- login flows --------------------------------------------------------

  /// Email/password login. Throws [AuthException] on failure and
  /// [NotTrainerException] when the account is not a trainer.
  Future<void> login({required String email, required String password}) async {
    _userActionStarted = true;
    final tokens = await _repo.login(email: email, password: password);
    await _establish(tokens);
  }

  /// Creates a trainer account then signs in. Throws [AuthException].
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async {
    _userActionStarted = true;
    final tokens = await _repo.register(
      email: email,
      password: password,
      name: name,
      inviteCode: inviteCode,
    );
    await _establish(tokens);
  }

  /// Social sign-in (kakao / google). Throws [AuthException].
  Future<void> socialLogin({required String provider}) async {
    _userActionStarted = true;
    final tokens = await _repo.socialLogin(
      provider: provider,
      token: 'demo-$provider-token',
    );
    await _establish(tokens);
  }

  /// Persists fresh tokens and attaches the trainer profile from `/me`.
  /// Any failure clears the just-issued tokens and rethrows an
  /// [AuthException] (role rejection keeps its specific message).
  Future<void> _establish(TrainerAuthTokens tokens) async {
    await _persist(tokens);
    _setAccessToken(tokens.access);
    try {
      final profile = await _repo.fetchProfile(tokens.access);
      if (!mounted) return;
      state = SessionState(
        status: SessionStatus.authenticated,
        profile: profile,
      );
    } catch (e) {
      // 로그인·가입·소셜이 실패한 것이라 이 만료도 그 사용자 행동의 일부다 —
      // 사용자 행동 가드에 막히면 거부된 자격이 저장소에 남는다.
      await _expire(userInitiated: true);
      if (e is AuthException) rethrow;
      throw const AuthException(AuthFailure.unknown);
    }
  }

  // --- demo / sign-out ----------------------------------------------------

  /// Enters demo mode — skip login, no token, browse with mock data.
  /// Not persisted, so a restart returns to the signed-out state.
  void enterDemo() {
    _userActionStarted = true;
    // Demo is intentionally in-memory only. Queue the clear so it also wins
    // over any launch-time refresh save that is already in flight.
    unawaited(_clearPersistedTokens());
    _setAccessToken(null);
    state = const SessionState(status: SessionStatus.demo);
  }

  /// Replaces the authenticated or demo profile after a successful profile
  /// mutation. Demo keeps its status and only updates the in-memory snapshot.
  /// Keeping this in the session owner prevents MY, the sidebar, and
  /// subsequent consumers from showing different snapshots.
  void replaceProfile(TrainerProfile profile) {
    final status = state.status;
    if (status != SessionStatus.authenticated && status != SessionStatus.demo) {
      return;
    }
    state = SessionState(status: status, profile: profile);
  }

  /// Signs out — clears persisted tokens and returns to the login screen.
  Future<void> signOut() async {
    _userActionStarted = true;
    // 사용자가 직접 요청한 만료다 — 자기 자신의 가드에 막히면 안 된다.
    await _expire(userInitiated: true);
  }

  // --- helpers ------------------------------------------------------------

  Future<void> _persist(TrainerAuthTokens tokens) async {
    try {
      await _serializeTokenStorage(
        () =>
            _tokens.saveTokens(access: tokens.access, refresh: tokens.refresh),
      );
    } catch (_) {
      // Secure storage unavailable — proceed with the in-memory token.
    }
  }

  Future<void> _clearPersistedTokens() async {
    try {
      await _serializeTokenStorage(_tokens.clear);
    } catch (_) {}
  }

  Future<void> _serializeTokenStorage(Future<void> Function() operation) {
    final result = _tokenStorageTail.then((_) => operation());
    // Keep the queue usable even when a platform storage operation fails;
    // the caller still receives [result] and applies its existing error policy.
    _tokenStorageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  /// Clears tokens + in-memory state and lands signed out.
  /// 세션을 끝내고 저장된 토큰을 지운다.
  ///
  /// [userInitiated] 는 **이 만료가 지금 진행 중인 사용자 행동의 일부인가**다.
  /// 로그아웃, 그리고 로그인·가입·소셜이 거부되어 방금 받은 자격을 지우는 경우가
  /// 여기 해당한다. 이때 사용자 행동 가드를 적용하면 그 행동이 자기 자신의 가드에
  /// 막혀 아무 일도 일어나지 않는다.
  ///
  /// 기본값(false)은 복구가 만료로 흘러가는 경우다. 이때는 **지우기 전에** 확인한다.
  /// 느린 복구 중에 로그인이 끝났다면 저장소에는 방금 받은 토큰이 들어 있고, 저장소
  /// 작업은 큐로 직렬화되어 나중에 들어간 것이 뒤에 실행되므로, 뒤늦은 만료의 `clear`
  /// 는 그 저장을 **확실히** 덮어쓴다 — 화면은 로그인 상태인데 다음 실행에서 로그아웃된다.
  Future<void> _expire({bool userInitiated = false}) async {
    if (!mounted) return;
    if (!userInitiated && _userActionStarted) return;
    await _clearPersistedTokens();
    // `_setAccessToken` reads a provider — guard it behind the mounted check
    // so it never runs against a disposed container during teardown.
    if (!mounted) return;
    if (!userInitiated && _userActionStarted) return;
    _setAccessToken(null);
    state = const SessionState(status: SessionStatus.signedOut);
  }
}

/// Exposes the trainer session state + controller app-wide.
final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(ref),
      name: 'trainerSession',
    );
