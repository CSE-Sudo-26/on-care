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
    } on AuthException {
      if (_userActionStarted) return;
      await _expire();
    } catch (_) {
      // Transient (network/server) — keep tokens, just show signed out.
      if (!mounted || _userActionStarted) return;
      _setAccessToken(null);
      state = const SessionState(status: SessionStatus.signedOut);
    }
  }

  Future<void> _refreshAndResolve(String refresh) async {
    if (_userActionStarted) return;
    final TrainerAuthTokens tokens;
    try {
      tokens = await _repo.refresh(refresh);
    } catch (_) {
      // The refresh failed — but a user action (login/demo/sign-out) may
      // have landed during the slow call; don't clobber it. Otherwise the
      // session really is expired.
      if (_userActionStarted) return;
      await _expire();
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
      await _expire();
      if (e is AuthException) rethrow;
      throw const AuthException('로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.');
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

  /// Replaces the authenticated profile after a successful `/trainer/me`
  /// mutation. Keeping this in the session owner prevents MY, the sidebar,
  /// and subsequent consumers from showing different snapshots.
  void replaceProfile(TrainerProfile profile) {
    if (state.status != SessionStatus.authenticated) return;
    state = SessionState(status: SessionStatus.authenticated, profile: profile);
  }

  /// Signs out — clears persisted tokens and returns to the login screen.
  Future<void> signOut() async {
    _userActionStarted = true;
    await _expire();
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
  Future<void> _expire() async {
    await _clearPersistedTokens();
    // `_setAccessToken` reads a provider — guard it behind the mounted check
    // so it never runs against a disposed container during teardown.
    if (!mounted) return;
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
