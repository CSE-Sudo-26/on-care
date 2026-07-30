import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/ai_routine/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_repository.dart';

/// Assigns/reads a member's routines against the FastAPI backend. A routine
/// assigned here is what the member app receives via `/me/coach/routines`.
/// Selected when `USE_MOCK_API=false` (see [trainerRoutineRepositoryProvider]).
class DioTrainerRoutineRepository implements TrainerRoutineRepository {
  DioTrainerRoutineRepository(this._dio);

  final Dio _dio;

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
