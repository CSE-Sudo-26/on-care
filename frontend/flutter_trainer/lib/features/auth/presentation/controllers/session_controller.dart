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
  /// means the trainer stays logged in (with the seed profile);
  /// otherwise they land signed out. Demo mode is never persisted.
  void _restore() {
    final token = _tokenStore.readToken();
    if (token != null) {
      state = const SessionState(
        status: SessionStatus.authenticated,
        profile: seedTrainerProfile,
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
    await _tokenStore.saveToken(token);
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
