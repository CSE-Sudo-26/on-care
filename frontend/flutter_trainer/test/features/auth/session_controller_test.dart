import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:oncare_trainer/core/storage/session_token_store.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';

/// Builds a ProviderContainer wired to a fresh mock SharedPreferences.
Future<ProviderContainer> _makeContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SessionController', () {
    test('restores to signedOut when no token is persisted', () async {
      final container = await _makeContainer();

      final state = container.read(sessionControllerProvider);

      expect(state.status, SessionStatus.signedOut);
      expect(state.canEnterApp, isFalse);
      expect(state.profile, isNull);
    });

    test('restores to authenticated when a token is persisted', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'trainer_access_token': 'demo-trainer-token-existing',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(sessionControllerProvider);

      expect(state.status, SessionStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.profile?.name, '김트레이너');
      expect(state.profile?.email, 'trainer@oncare.com');
    });

    test(
      'login with non-empty credentials authenticates and persists',
      () async {
        final container = await _makeContainer();
        final controller = container.read(sessionControllerProvider.notifier);

        await controller.login(email: 'trainer@oncare.com', password: 'pw');

        final state = container.read(sessionControllerProvider);
        expect(state.status, SessionStatus.authenticated);
        expect(state.canEnterApp, isTrue);
        expect(state.profile, isNotNull);

        // Token persisted → survives a "restart".
        expect(
          container.read(sessionTokenStoreProvider).readToken(),
          isNotNull,
        );
      },
    );

    test('login with empty credentials throws and stays signed out', () async {
      final container = await _makeContainer();
      final controller = container.read(sessionControllerProvider.notifier);

      await expectLater(
        controller.login(email: '   ', password: ''),
        throwsA(isA<AuthException>()),
      );

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.signedOut);
      expect(container.read(sessionTokenStoreProvider).readToken(), isNull);
    });

    test('enterDemo grants app access without persisting a token', () async {
      final container = await _makeContainer();
      final controller = container.read(sessionControllerProvider.notifier);

      controller.enterDemo();

      final state = container.read(sessionControllerProvider);
      expect(state.status, SessionStatus.demo);
      expect(state.canEnterApp, isTrue);
      expect(state.isAuthenticated, isFalse);
      // Demo is in-memory only — nothing persisted.
      expect(container.read(sessionTokenStoreProvider).readToken(), isNull);
    });

    test('signOut clears the token and returns to signedOut', () async {
      final container = await _makeContainer();
      final controller = container.read(sessionControllerProvider.notifier);

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
      expect(container.read(sessionTokenStoreProvider).readToken(), isNull);
    });
  });
}
