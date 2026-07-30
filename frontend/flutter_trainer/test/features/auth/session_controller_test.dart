import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/storage/secure_token_store.dart';
import 'package:oncare_trainer/features/auth/data/repositories/dio_trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';

const _mockConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost/v1',
  useMockApi: true,
);

/// Builds a container wired to fresh mock secure storage (in mock-API
/// mode) plus an optional [repoOverride] to inject a fake auth repository.
ProviderContainer _makeContainer({
  Map<String, String> tokens = const <String, String>{},
  Override? repoOverride,
}) {
  FlutterSecureStorage.setMockInitialValues(Map<String, String>.of(tokens));
  final container = ProviderContainer(
    overrides: <Override>[
      appConfigProvider.overrideWithValue(_mockConfig),
      ?repoOverride,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the async restore / login microtask chain settle.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  group('SessionController restore', () {
    test('signed out when no token is persisted', () async {
      final container = _makeContainer();
      container.read(sessionControllerProvider.notifier);
      await _settle();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.signedOut);
      expect(state.canEnterApp, isFalse);
      expect(state.profile, isNull);
    });

    test('authenticated with profile when a token is persisted', () async {
      final container = _makeContainer(
        tokens: <String, String>{'access_token': 'demo-existing'},
      );
      container.read(sessionControllerProvider.notifier);
      await _settle();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.authenticated);
      expect(state.profile?.name, '김트레이너');
      expect(state.profile?.email, 'trainer@oncare.com');
    });

    test('rotates tokens when the access token is expired (401)', () async {
      final fake = _FakeAuthRepository()
        ..profileFailuresBeforeSuccess = 1; // first fetch 401, then ok
      final container = _makeContainer(
        tokens: <String, String>{
          'access_token': 'stale',
          'refresh_token': 'good-refresh',
        },
        repoOverride: trainerAuthRepositoryProvider.overrideWithValue(fake),
      );
      container.read(sessionControllerProvider.notifier);
      await _settle();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.authenticated,
      );
      expect(fake.refreshCalls, 1);
      // The rotated access token is now persisted.
      expect(
        await container.read(secureTokenStoreProvider).readAccessToken(),
        'rotated-access',
      );
    });

    test('a user action during restore is not clobbered by the late restore',
        () async {
      // Restore is in flight against a slow /me; the user picks demo before
      // it resolves. The late restore must not overwrite the demo session.
      final fake = _FakeAuthRepository()
        ..profileDelay = const Duration(milliseconds: 200);
      final container = _makeContainer(
        tokens: <String, String>{
          'access_token': 'stored',
          'refresh_token': 'r',
        },
        repoOverride: trainerAuthRepositoryProvider.overrideWithValue(fake),
      );
      final controller = container.read(sessionControllerProvider.notifier);

      // Do NOT settle — restore is still awaiting the token read + slow /me.
      controller.enterDemo();
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.demo,
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.demo,
      );
    });

    test('signs out when refresh also fails', () async {
      final fake = _FakeAuthRepository()
        ..profileFailuresBeforeSuccess = 1
        ..refreshThrows = true;
      final container = _makeContainer(
        tokens: <String, String>{
          'access_token': 'stale',
          'refresh_token': 'bad-refresh',
        },
        repoOverride: trainerAuthRepositoryProvider.overrideWithValue(fake),
      );
      container.read(sessionControllerProvider.notifier);
      await _settle();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.signedOut,
      );
      expect(
        await container.read(secureTokenStoreProvider).readAccessToken(),
        isNull,
      );
    });

    test('keeps the stored tokens on a transient network failure at restore',
        () async {
      final fake = _FakeAuthRepository()..profileThrowsNetwork = true;
      final container = _makeContainer(
        tokens: <String, String>{
          'access_token': 'valid',
          'refresh_token': 'valid-refresh',
        },
        repoOverride: trainerAuthRepositoryProvider.overrideWithValue(fake),
      );
      container.read(sessionControllerProvider.notifier);
      await _settle();

      // Transient failure → signed out, but the tokens survive so a later
      // relaunch can restore (not a forced sign-out that discards a valid
      // session).
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.signedOut,
      );
      final store = container.read(secureTokenStoreProvider);
      expect(await store.readAccessToken(), 'valid');
      expect(await store.readRefreshToken(), 'valid-refresh');
    });

    test('refresh keeps the existing refresh token when the response omits one',
        () async {
      final fake = _FakeAuthRepository()
        ..profileFailuresBeforeSuccess = 1 // first fetch 401 → triggers refresh
        ..refreshReturnsEmptyRefresh = true;
      final container = _makeContainer(
        tokens: <String, String>{
          'access_token': 'stale',
          'refresh_token': 'keep-me',
        },
        repoOverride: trainerAuthRepositoryProvider.overrideWithValue(fake),
      );
      container.read(sessionControllerProvider.notifier);
      await _settle();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.authenticated,
      );
      final store = container.read(secureTokenStoreProvider);
      expect(await store.readAccessToken(), 'rotated-access');
      // Backend rotated only the access token → the old refresh is preserved.
      expect(await store.readRefreshToken(), 'keep-me');
    });

    test('a user action during a slow refresh is not clobbered', () async {
      // stale access → 401 → refresh (slow); the user picks demo mid-refresh.
      final fake = _FakeAuthRepository()
        ..profileFailuresBeforeSuccess = 1
        ..refreshDelay = const Duration(milliseconds: 200);
      final container = _makeContainer(
        tokens: <String, String>{'access_token': 'stale', 'refresh_token': 'r'},
        repoOverride: trainerAuthRepositoryProvider.overrideWithValue(fake),
      );
      final controller = container.read(sessionControllerProvider.notifier);

      // Let restore hit the 401 and start the slow refresh, then act.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      controller.enterDemo();
      expect(container.read(sessionControllerProvider).status, SessionStatus.demo);

      // The late refresh resolves — it must NOT overwrite the demo session.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(container.read(sessionControllerProvider).status, SessionStatus.demo);
    });
  });

  group('SessionController login', () {
    test('authenticates and persists tokens', () async {
      final container = _makeContainer();
      final controller = container.read(sessionControllerProvider.notifier);
      await _settle();

      await controller.login(email: 'trainer@oncare.com', password: 'pw');

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.authenticated);
      expect(state.profile, isNotNull);
      expect(
        await container.read(secureTokenStoreProvider).readAccessToken(),
        isNotNull,
      );
    });

    test('empty credentials throw and stay signed out', () async {
      final container = _makeContainer();
      final controller = container.read(sessionControllerProvider.notifier);
      await _settle();

      await expectLater(
        controller.login(email: '   ', password: ''),
        throwsA(isA<AuthException>()),
      );
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.signedOut,
      );
    });

    test('rejects a non-trainer account and clears tokens', () async {
      final fake = _FakeAuthRepository()..profileThrowsNotTrainer = true;
      final container = _makeContainer(
        repoOverride: trainerAuthRepositoryProvider.overrideWithValue(fake),
      );
      final controller = container.read(sessionControllerProvider.notifier);
      await _settle();

      await expectLater(
        controller.login(email: 'member@oncare.com', password: 'pw'),
        throwsA(isA<NotTrainerException>()),
      );
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.signedOut,
      );
      expect(
        await container.read(secureTokenStoreProvider).readAccessToken(),
        isNull,
      );
    });
  });

  group('SessionController demo & sign-out', () {
    test('enterDemo grants access without persisting a token', () async {
      final container = _makeContainer();
      final controller = container.read(sessionControllerProvider.notifier);
      await _settle();

      controller.enterDemo();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.demo);
      expect(state.canEnterApp, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(
        await container.read(secureTokenStoreProvider).readAccessToken(),
        isNull,
      );
    });

    test('signOut clears tokens and returns to signed out', () async {
      final container = _makeContainer();
      final controller = container.read(sessionControllerProvider.notifier);
      await _settle();
      await controller.login(email: 'trainer@oncare.com', password: 'pw');
      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.authenticated,
      );

      await controller.signOut();

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.signedOut,
      );
      expect(
        await container.read(secureTokenStoreProvider).readAccessToken(),
        isNull,
      );
    });
  });
}

/// A configurable fake for controller-level tests (role gate, refresh).
class _FakeAuthRepository implements TrainerAuthRepository {
  int profileFailuresBeforeSuccess = 0;
  bool profileThrowsNotTrainer = false;
  bool profileThrowsNetwork = false;
  bool refreshThrows = false;
  bool refreshReturnsEmptyRefresh = false;
  Duration profileDelay = Duration.zero;
  Duration refreshDelay = Duration.zero;
  int refreshCalls = 0;
  int _profileCalls = 0;

  TrainerAuthTokens _tokens(String tag) =>
      TrainerAuthTokens(access: '$tag-access', refresh: '$tag-refresh');

  @override
  Future<TrainerAuthTokens> login({
    required String email,
    required String password,
  }) async => _tokens('login');

  @override
  Future<TrainerAuthTokens> register({
    required String email,
    required String password,
    required String name,
  }) async => _tokens('register');

  @override
  Future<TrainerAuthTokens> socialLogin({
    required String provider,
    required String token,
  }) async => _tokens('social');

  @override
  Future<TrainerAuthTokens> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshDelay > Duration.zero) await Future<void>.delayed(refreshDelay);
    if (refreshThrows) throw const AuthException('refresh failed');
    return TrainerAuthTokens(
      access: 'rotated-access',
      refresh: refreshReturnsEmptyRefresh ? '' : 'rotated-refresh',
    );
  }

  @override
  Future<TrainerProfile> fetchProfile(String accessToken) async {
    _profileCalls++;
    if (profileDelay > Duration.zero) await Future<void>.delayed(profileDelay);
    if (profileThrowsNotTrainer) throw const NotTrainerException();
    if (profileThrowsNetwork) throw const NetworkError(message: 'net down');
    if (_profileCalls <= profileFailuresBeforeSuccess) {
      throw const UnauthorizedError(message: '401');
    }
    return seedTrainerProfile;
  }
}
