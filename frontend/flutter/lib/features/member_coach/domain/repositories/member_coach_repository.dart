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

  /// Records an assigned routine once in the member's exercise history.
  Future<CoachRoutine> completeRoutine(
    String routineId, {
    required int minutes,
    String intensity = 'moderate',
    String memberNote = '',
  });

  /// PT sessions the coach booked. The trainer owns the schedule — the
  /// member reads it only. (#490)
  Future<List<CoachSession>> fetchSessions();

  /// The chat thread (oldest → newest).
  Future<List<CoachMessage>> fetchChat();

  /// Watches the chat while its screen is active. Real API implementations
  /// poll the shared thread; demo implementations emit their in-memory state.
  Stream<List<CoachMessage>> watchChat();

  /// Sends a message to the coach. No-ops on blank text.
  Future<void> sendMessage(String text);

  /// Marks the thread read up to the newest coach message.
  Future<void> markRead();

  /// Unread coach-sent message count for the entry badge.
  Future<int> unreadCount();

  /// 트레이너가 나에게 보낸, 아직 답하지 않은 담당 요청. (#919)
  Future<List<CoachInvite>> fetchInvites();

  /// 요청을 수락한다 — 담당 관계는 이 호출로 생긴다.
  Future<void> acceptInvite(String inviteId);

  /// 요청을 거절한다. 담당은 생기지 않는다.
  Future<void> rejectInvite(String inviteId);
}
