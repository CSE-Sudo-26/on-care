import 'package:dio/dio.dart';

import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';

/// Network-side [ExerciseRepository]. dev/local builds get served by
/// `LocalApiInterceptor` (drift-backed); prod hits FastAPI.
class DioExerciseRepository implements ExerciseRepository {
  DioExerciseRepository(this._dio);
  final Dio _dio;

  @override
  Future<ExerciseWeek> fetchThisWeek() async {
    final res = await _dio.get<Map<String, Object?>>('/exercise/weeks/current');
    return ExerciseWeek.fromJson(res.data!);
  }

  @override
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async {
    final res = await _dio.post<Map<String, Object?>>(
      '/exercise/sessions',
      data: <String, Object?>{
        'type': type.name,
        'minutes': minutes,
        'calories': calories,
        'intensity': intensity.name,
        'day_label': dayLabel,
      },
    );
    return ExerciseSession.fromJson(res.data!);
  }

  @override
  Future<void> deleteSession(String id) async {
    await _dio.delete<Map<String, Object?>>('/exercise/sessions/$id');
  }

  @override
  Future<ExerciseSession> updateSession({
    required String id,
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async {
    final res = await _dio.put<Map<String, Object?>>(
      '/exercise/sessions/$id',
      data: <String, Object?>{
        'type': type.name,
        'minutes': minutes,
        'calories': calories,
        'intensity': intensity.name,
        'day_label': dayLabel,
      },
    );
    return ExerciseSession.fromJson(res.data!);
  }
}
