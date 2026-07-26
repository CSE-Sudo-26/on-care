import 'package:oncare_trainer/shared/models/trainer_profile.dart';

/// Lifecycle of the trainer session.
///
/// Designed fresh for the trainer app (the user app's auth logic is not
/// reused — it has no notion of a trainer account). Mirrors the same
/// four-state shape so the two On-Care apps stay conceptually aligned.
enum SessionStatus {
  /// Session not yet resolved (during the initial restore).
  unknown,

  /// No session — the login screen is shown.
  signedOut,

  /// Skipped login — browsing with mock data, no token.
  demo,

  /// Logged in with a (mock) token and a trainer profile attached.
  authenticated,
}

/// Immutable snapshot of the current session.
class SessionState {
  /// Creates a session snapshot. [profile] is non-null only when
  /// [status] is [SessionStatus.authenticated].
  const SessionState({this.status = SessionStatus.unknown, this.profile});

  /// Current lifecycle state.
  final SessionStatus status;

  /// The signed-in trainer's profile, or `null` when not authenticated.
  final TrainerProfile? profile;

  /// Whether the trainer is logged in with a token.
  bool get isAuthenticated => status == SessionStatus.authenticated;

  /// Whether the app content is reachable — either a real (mock) login
  /// or demo mode. The router's auth gate keys off this.
  bool get canEnterApp =>
      status == SessionStatus.authenticated || status == SessionStatus.demo;
}
