import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/dio_trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';

/// Assigns a routine to a member and reads their assigned routines.
///
/// Assigning is how a member *receives* a routine (the same record the
/// member app reads via `/me/coach/routines`). Two implementations sit
/// behind this contract, selected by [trainerRoutineRepositoryProvider] via
/// [AppConfig.useMockApi]:
///  * [MockTrainerRoutineRepository] — demo / `USE_MOCK_API=true` (no-op
///    send; the demo has no member app to receive it);
///  * [DioTrainerRoutineRepository] — the real FastAPI backend.
abstract interface class TrainerRoutineRepository {
  /// Assigns [routine] to [memberId] (POST /trainer/clients/{id}/routines).
  ///
  /// [clientRequestId] 는 **전송 시도**의 멱등키다. 재시도할 때 같은 값을 다시
  /// 넘기면 회원에게 같은 루틴이 두 번 배정되지 않는다(#581). 새 내용을 보낼
  /// 때만 새로 만든다 — 매 호출 새로 만들면 아무것도 막지 못한다.
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  });

  /// Assigns a whole program — one routine per session (#709).
  ///
  /// [payload] comes from `programAssignToJson`, which carries the session
  /// order and each session's exercises. A program with one session lands as
  /// the same single routine the flat path produces, so the member's screen
  /// does not suddenly grow a session label.
  Future<void> assignProgram(String memberId, Map<String, Object?> payload);

  /// The member's currently assigned routines (newest first).
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId);

  /// 배정한 루틴을 고친다(PUT). 보낸 필드만 바뀐다. (#504)
  ///
  /// 없는 루틴·남의 배정은 [StateError] — 배정 실패와 같은 규칙으로, 목과
  /// 실서버가 같은 예외를 낸다.
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  });

  /// 배정한 루틴을 철회한다(DELETE). 회원 앱에서도 사라진다. (#504)
  Future<void> deleteRoutine(String memberId, String routineId);
}

/// Demo no-op: the mock/demo build has no member backend to deliver to, so
/// assignment succeeds silently and the assigned list is empty. The visible
/// "전송됨" feedback in demo comes from the local chat/schedule writes.
class MockTrainerRoutineRepository implements TrainerRoutineRepository {
  const MockTrainerRoutineRepository();

  @override
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  }) async {}

  @override
  Future<void> assignProgram(
    String memberId,
    Map<String, Object?> payload,
  ) async {}

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[]);

  // 데모에는 배정 목록이 없으므로 고칠 것도 없다. 조용히 성공하면 화면이
  // '고쳤다'고 말하게 되므로, 배정과 달리 없는 것을 지적한다.
  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async => throw StateError('routine not found: $routineId');

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async =>
      throw StateError('routine not found: $routineId');
}

/// Selects the real Dio-backed routine repository against the FastAPI
/// backend, or the demo no-op for `USE_MOCK_API=true`.
final trainerRoutineRepositoryProvider = Provider<TrainerRoutineRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockApi) {
    return const MockTrainerRoutineRepository();
  }
  return DioTrainerRoutineRepository(ref.watch(dioProvider));
}, name: 'trainerRoutineRepository');

/// Streams the routines currently assigned to a member (newest first).
/// Empty in demo mode — [MockTrainerRoutineRepository] has no member
/// backend to deliver to.
final assignedRoutinesProvider =
    StreamProvider.family<List<AssignedRoutine>, String>((ref, memberId) {
      return ref
          .watch(trainerRoutineRepositoryProvider)
          .watchAssignedRoutines(memberId);
    });
