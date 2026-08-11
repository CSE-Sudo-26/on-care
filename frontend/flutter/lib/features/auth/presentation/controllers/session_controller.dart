import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/auth_token.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/core/session/session_feature_reset.dart';
import 'package:oncare/core/storage/secure_token_store.dart';

enum SessionStatus { unknown, signedOut, demo, authenticated }

class SessionState {
  const SessionState({this.status = SessionStatus.unknown});
  final SessionStatus status;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get canEnterApp =>
      status == SessionStatus.authenticated || status == SessionStatus.demo;
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionState()) {
    _restore();
  }

  final Ref _ref;

  /// 사용자가 시작한 흐름(로그인·가입·데모·로그아웃)이 시작됐는가.
  ///
  /// 복구는 네트워크 왕복을 포함해 느리다. 그 사이 사용자가 로그인 버튼을 누르면,
  /// 뒤늦게 끝난 복구가 그 결과를 덮어써 방금 로그인한 세션이 사라진다. 사용자 행동이
  /// 항상 이긴다.
  bool _userActionStarted = false;

  void _setToken(String? token) {
    _ref.read(authAccessTokenProvider.notifier).state = token;
  }

  void _resetFeatureState() {
    _ref.read(sessionFeatureResetProvider)();
  }

  /// 저장된 토큰으로 세션을 되살린다.
  ///
  /// 토큰이 있다는 것만으로 인증 상태로 넘어가지 않는다. 접근 토큰 수명은 하루라,
  /// 존재만 보고 통과시키면 다음 날 앱을 켰을 때 **로그인된 화면이 뜨지만 모든 요청이
  /// 실패하고** 수동 로그아웃 말고는 빠져나갈 길이 없었다. 유효한지 확인하고, 만료면
  /// 갱신 토큰으로 한 번 회전한다.
  Future<void> _restore() async {
    // 두 토큰을 따로 읽는다 — 갱신 토큰 읽기가 실패했다고 멀쩡히 읽힌 접근 토큰까지
    // 버릴 이유가 없다.
    String? access;
    String? refresh;
    try {
      access = await _ref.read(secureTokenStoreProvider).readAccessToken();
    } catch (_) {
      access = null; // secure storage unavailable → treat as signed out
    }
    try {
      refresh = await _ref.read(secureTokenStoreProvider).readRefreshToken();
    } catch (_) {
      refresh = null; // 갱신은 못 해도 접근 토큰만으로 복구를 시도할 수 있다.
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

  /// [access] 로 프로필을 조회해 세션을 확정한다. 인증 실패면 [refresh] 로 한 번
  /// 회전한다.
  ///
  /// 일시적 실패(네트워크·서버)는 **토큰을 지우지 않고** 로그아웃 상태로만 둔다.
  /// 지하철에서 앱을 켰다고 저장된 세션을 잃으면 안 된다.
  Future<void> _resolveSession({
    required String access,
    required String refresh,
    required bool allowRefresh,
  }) async {
    if (_userActionStarted) return;
    try {
      // 아직 세션에 넣지 않은 토큰으로 찔러 본다. 유효한지 모르는 토큰을 먼저
      // 세션에 넣으면 그 사이 앱이 만료된 토큰으로 로그인 상태가 된다.
      await _ref.read(dioProvider).get<Map<String, Object?>>(
        '/users/me',
        options: Options(
          headers: <String, Object?>{'Authorization': 'Bearer $access'},
        ),
      );
      if (!mounted || _userActionStarted) return;
      _setToken(access);
      state = const SessionState(status: SessionStatus.authenticated);
    } on DioException catch (e) {
      if (!mounted || _userActionStarted) return;
      final int? code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        if (allowRefresh && refresh.isNotEmpty) {
          await _refreshAndResolve(refresh);
        } else {
          await _expire();
        }
        return;
      }
      // 그 밖의 응답·연결 실패는 일시적으로 본다. 토큰은 남겨 둔다.
      _setToken(null);
      state = const SessionState(status: SessionStatus.signedOut);
    } catch (_) {
      if (!mounted || _userActionStarted) return;
      _setToken(null);
      state = const SessionState(status: SessionStatus.signedOut);
    }
  }

  /// 갱신 토큰으로 접근 토큰을 회전하고 다시 확정한다.
  Future<void> _refreshAndResolve(String refresh) async {
    if (_userActionStarted) return;
    final Map<String, Object?>? data;
    try {
      final res = await _ref.read(dioProvider).post<Map<String, Object?>>(
        '/auth/refresh',
        data: <String, Object?>{'refresh_token': refresh},
      );
      data = res.data;
    } catch (_) {
      // 회전이 실패했다 — 다만 느린 호출 중에 사용자가 로그인·데모를 시작했을 수
      // 있으니 그 결과를 덮지 않는다.
      if (_userActionStarted) return;
      await _expire();
      return;
    }
    if (!mounted || _userActionStarted) return;

    final String access = (data?['access_token'] as String?) ?? '';
    if (access.isEmpty) {
      await _expire();
      return;
    }
    // 갱신 토큰을 새로 주지 않는 서버도 있다. 그때는 쓰던 것을 유지해야 다음 만료
    // 때도 되살릴 수 있다.
    final String rotated = (data?['refresh_token'] as String?) ?? '';
    final String nextRefresh = rotated.isEmpty ? refresh : rotated;
    try {
      await _ref
          .read(secureTokenStoreProvider)
          .saveTokens(access: access, refresh: nextRefresh);
    } catch (_) {
      // 저장에 실패해도 이번 세션은 메모리 토큰으로 진행한다.
    }
    if (!mounted || _userActionStarted) return;
    // 방금 회전한 토큰마저 거부되면 더 시도하지 않는다.
    await _resolveSession(
      access: access,
      refresh: nextRefresh,
      allowRefresh: false,
    );
  }

  /// 세션이 정말 끝났다 — 저장된 토큰을 지우고 로그인 화면으로 보낸다.
  Future<void> _expire() async {
    try {
      await _ref.read(secureTokenStoreProvider).clear();
    } catch (_) {}
    if (!mounted || _userActionStarted) return;
    _setToken(null);
    state = const SessionState(status: SessionStatus.signedOut);
  }

  /// Persist tokens from an auth response and flip to authenticated.
  /// Shared by [login] and [socialLogin]. Throws if no access token.
  Future<void> _applyTokens(
    Map<String, Object?>? data, {
    required String label,
  }) async {
    final access = (data?['access_token'] as String?) ?? '';
    final refresh = (data?['refresh_token'] as String?) ?? '';
    if (access.isEmpty) throw Exception('$label 응답에 토큰이 없습니다.');
    try {
      await _ref
          .read(secureTokenStoreProvider)
          .saveTokens(access: access, refresh: refresh);
    } catch (_) {
      // secure storage 저장 실패해도 세션 메모리 토큰으로 진행
    }
    _setToken(access);
    _resetFeatureState();
    state = const SessionState(status: SessionStatus.authenticated);
  }

  /// Email/password login → POST /auth/login (OAuth2 form). Throws on failure.
  Future<void> login({required String email, required String password}) async {
    _userActionStarted = true;
    final dio = _ref.read(dioProvider);
    final res = await dio.post<Map<String, Object?>>(
      '/auth/login',
      data: <String, Object?>{'username': email, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    await _applyTokens(res.data, label: '로그인');
  }

  /// Social login — exchanges a provider (kakao/google) token for our
  /// session via POST /auth/social/{provider}. Throws on failure.
  Future<void> socialLogin({
    required String provider,
    required String token,
  }) async {
    _userActionStarted = true;
    final dio = _ref.read(dioProvider);
    final res = await dio.post<Map<String, Object?>>(
      '/auth/social/$provider',
      data: <String, Object?>{'token': token},
    );
    await _applyTokens(res.data, label: '소셜 로그인');
  }

  /// Register a new account → POST /auth/register (returns the created
  /// user, not a token), then log in with the same credentials so the
  /// user lands authenticated. Throws on failure (e.g. 409 duplicate).
  Future<void> register({
    required String email,
    required String password,
    String name = '',
  }) async {
    _userActionStarted = true;
    final dio = _ref.read(dioProvider);
    await dio.post<Map<String, Object?>>(
      '/auth/register',
      data: <String, Object?>{
        'email': email,
        'password': password,
        'name': name,
      },
    );
    await login(email: email, password: password);
  }

  /// Skip auth — demo mode. No token; the backend demo-fallback serves data.
  void enterDemo() {
    _userActionStarted = true;
    _setToken(null);
    _resetFeatureState();
    state = const SessionState(status: SessionStatus.demo);
  }

  Future<void> signOut() async {
    _userActionStarted = true;
    try {
      await _ref.read(secureTokenStoreProvider).clear();
    } catch (_) {}
    _setToken(null);
    _resetFeatureState();
    state = const SessionState(status: SessionStatus.signedOut);
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(ref),
      name: 'session',
    );
