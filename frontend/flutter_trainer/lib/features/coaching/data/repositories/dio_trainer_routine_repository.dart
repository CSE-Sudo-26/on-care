import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';

/// Assigns/reads a member's routines against the FastAPI backend. A routine
/// assigned here is what the member app receives via `/me/coach/routines`.
/// Selected when `USE_MOCK_API=false` (see [trainerRoutineRepositoryProvider]).
class DioTrainerRoutineRepository implements TrainerRoutineRepository {
  DioTrainerRoutineRepository(this._dio);

  final Dio _dio;

  /// Assigns [routine] to [memberId].
  ///
  /// NOT idempotent: `POST /trainer/clients/{id}/routines` inserts a fresh
  /// `rt-{uuid}` row on every call, with no client-request-id/dedup key
  /// today. If this throws after a network timeout, the backend may have
  /// already committed the assign before the client gave up waiting —
  /// blindly retrying can leave the member with two copies of the same
  /// routine. Callers that retry on failure should special-case a network/
  /// timeout error (ambiguous outcome) rather than assume a clean retry is
  /// always safe (review; a full fix needs a backend idempotency key).
  @override
  Future<void> assignRoutine(String memberId, AssignedRoutine routine) async {
    final encodedId = Uri.encodeComponent(memberId);
    try {
      await _dio.post<Map<String, Object?>>(
        '/trainer/clients/$encodedId/routines',
        data: assignRoutineToJson(routine),
      );
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async {
    // 보낼 필드만 담는다 — 서버의 부분 수정 규약(#495)에서 명시적 null 은 422 다.
    final body = <String, Object?>{
      if (name case final String value) 'name': value,
      if (minutes case final int value) 'minutes': value,
      if (type case final String value) 'type': value,
      if (reason case final String value) 'reason': value,
    };
    await _routineCall(
      () => _dio.put<Map<String, Object?>>(
        '/trainer/clients/${Uri.encodeComponent(memberId)}'
        '/routines/${Uri.encodeComponent(routineId)}',
        data: body,
      ),
      routineId,
    );
  }

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async {
    await _routineCall(
      () => _dio.delete<Map<String, Object?>>(
        '/trainer/clients/${Uri.encodeComponent(memberId)}'
        '/routines/${Uri.encodeComponent(routineId)}',
      ),
      routineId,
    );
  }

  /// 404(없음·남의 배정)는 [StateError] 로 옮긴다 — 목과 실서버가 같은 예외를
  /// 내야 화면이 한 갈래만 다룬다. 나머지는 [AppError].
  Future<void> _routineCall(
    Future<void> Function() call,
    String routineId,
  ) async {
    try {
      await call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw StateError('routine not found: $routineId');
      }
      throw AppError.fromDio(e);
    }
  }

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream<List<AssignedRoutine>>.fromFuture(_fetch(memberId));

  Future<List<AssignedRoutine>> _fetch(String memberId) async {
    final encodedId = Uri.encodeComponent(memberId);
    try {
      final res = await _dio.get<List<dynamic>>(
        '/trainer/clients/$encodedId/routines',
      );
      final data = res.data ?? const <dynamic>[];
      return data
          .map((item) {
            if (item is! Map<String, Object?>) {
              throw const FormatException(
                'Expected an object in the assigned-routine response.',
              );
            }
            return assignedRoutineFromJson(item);
          })
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }
}
