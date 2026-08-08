import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/member_coach/data/repositories/dio_member_coach_repository.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/repositories/member_coach_repository.dart';

/// Selects the real Dio-backed coach repository against the FastAPI backend,
/// or the in-memory demo for `USE_MOCK_API=true`. One mock instance per
/// provider lifetime so demo chat sends persist for the session.
final memberCoachRepositoryProvider = Provider<MemberCoachRepository>((ref) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return MockMemberCoachRepository();
  }
  return DioMemberCoachRepository(ref.watch(dioProvider));
}, name: 'memberCoachRepository');

/// The member's assigned coach (null when none).
final memberCoachProvider = FutureProvider<MemberCoach?>((ref) {
  return ref.watch(memberCoachRepositoryProvider).fetchCoach();
});

/// Routines the coach has assigned to the member.
final coachRoutinesProvider = FutureProvider<List<CoachRoutine>>((ref) {
  return ref.watch(memberCoachRepositoryProvider).fetchRoutines();
});

/// 트레이너가 잡아 준 PT 일정. 담당이 없거나 잡힌 일정이 없으면 빈 목록이라,
/// 화면이 늘어나지 않는다. (#490)
final coachSessionsProvider = FutureProvider<List<CoachSession>>((ref) {
  return ref.watch(memberCoachRepositoryProvider).fetchSessions();
}, name: 'coachSessions');

/// The member↔coach chat thread (oldest → newest).
final coachChatProvider = FutureProvider<List<CoachMessage>>((ref) {
  return ref.watch(memberCoachRepositoryProvider).fetchChat();
});

/// Unread coach-sent message count for the entry badge.
final coachUnreadProvider = FutureProvider<int>((ref) {
  return ref.watch(memberCoachRepositoryProvider).unreadCount();
});
