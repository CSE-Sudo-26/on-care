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
  Future<void> assignRoutine(String memberId, AssignedRoutine routine);

  /// The member's currently assigned routines (newest first).
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId);
}

/// Demo no-op: the mock/demo build has no member backend to deliver to, so
/// assignment succeeds silently and the assigned list is empty. The visible
/// "전송됨" feedback in demo comes from the local chat/schedule writes.
class MockTrainerRoutineRepository implements TrainerRoutineRepository {
  const MockTrainerRoutineRepository();

  @override
  Future<void> assignRoutine(String memberId, AssignedRoutine routine) async {}

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[]);
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
