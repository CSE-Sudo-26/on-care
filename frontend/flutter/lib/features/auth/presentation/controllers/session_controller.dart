import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/auth_token.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/core/storage/secure_token_store.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';

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

  void _setToken(String? token) {
    _ref.read(authAccessTokenProvider.notifier).state = token;
  }

  Future<void> _restore() async {
    String? token;
    try {
      token = await _ref.read(secureTokenStoreProvider).readAccessToken();
    } catch (_) {
      token = null; // secure storage unavailable → treat as signed out
    }
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      _setToken(token);
      state = const SessionState(status: SessionStatus.authenticated);
    } else {
      state = const SessionState(status: SessionStatus.signedOut);
    }
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
    state = const SessionState(status: SessionStatus.authenticated);
  }

  /// Email/password login → POST /auth/login (OAuth2 form). Throws on failure.
  Future<void> login({required String email, required String password}) async {
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
    _setToken(null);
    _ref.invalidate(consultationRequestControllerProvider);
    state = const SessionState(status: SessionStatus.demo);
  }

  Future<void> signOut() async {
    try {
      await _ref.read(secureTokenStoreProvider).clear();
    } catch (_) {}
    _setToken(null);
    _ref.invalidate(consultationRequestControllerProvider);
    state = const SessionState(status: SessionStatus.signedOut);
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(ref),
      name: 'session',
    );
