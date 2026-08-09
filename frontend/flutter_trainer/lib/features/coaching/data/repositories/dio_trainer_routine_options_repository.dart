import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_options_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';

/// Generates A/B routine options from the member's real data via the
/// FastAPI backend. Selected when `USE_MOCK_API=false`.
class DioTrainerRoutineOptionsRepository
    implements TrainerRoutineOptionsRepository {
  DioTrainerRoutineOptionsRepository(this._dio);

  final Dio _dio;

  @override
  Future<RoutineOptions> generate(
    String memberId, {
    required int availableMinutes,
    required String intensityPreference,
    required String trainerNote,
  }) async {
    final encodedId = Uri.encodeComponent(memberId);
    try {
      final res = await _dio.post<Map<String, Object?>>(
        '/trainer/clients/$encodedId/routine-options',
        data: <String, Object?>{
          'available_minutes': availableMinutes,
          'intensity_preference': intensityPreference,
          'trainer_note': trainerNote,
        },
      );
      final data = res.data;
      if (data == null) {
        // 문구는 화면이 붙인다 — 리포지토리는 로케일을 모른다. (#501)
        throw const ServerError();
      }
      return routineOptionsFromJson(data);
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }
}
