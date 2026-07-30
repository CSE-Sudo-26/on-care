import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';

/// The member's view of their assigned coach: profile, received routines,
/// and the shared chat thread (the same thread the trainer app writes to).
///
/// Two implementations sit behind this contract (selected by
/// [memberCoachRepositoryProvider] via `AppConfig.useMockApi`):
///  * `MockMemberCoachRepository` — demo / `USE_MOCK_API=true`;
///  * `DioMemberCoachRepository` — the real FastAPI backend.
abstract interface class MemberCoachRepository {
  /// The assigned coach, or `null` when the member has none yet (404).
  Future<MemberCoach?> fetchCoach();

  /// Routines the coach has assigned (newest first).
  Future<List<CoachRoutine>> fetchRoutines();

  /// The chat thread (oldest → newest).
  Future<List<CoachMessage>> fetchChat();

  /// Sends a message to the coach. No-ops on blank text.
  Future<void> sendMessage(String text);

  /// Marks the thread read up to the newest coach message.
  Future<void> markRead();

  /// Unread coach-sent message count for the entry badge.
  Future<int> unreadCount();
}
