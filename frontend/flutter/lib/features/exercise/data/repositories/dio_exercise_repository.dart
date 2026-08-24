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
  Future<ExerciseWeek> fetchWeek(DateTime weekStart) async {
    final res = await _dio.get<Map<String, Object?>>(
      '/exercise/weeks/current',
      queryParameters: <String, Object?>{'week_start': _dateString(weekStart)},
    );
    return ExerciseWeek.fromJson(res.data!);
  }

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    int? sets,
  }) async {
    final res = await _dio.post<Map<String, Object?>>(
      '/exercise/sessions',
      data: <String, Object?>{
        'type': type.name,
        'minutes': minutes,
        'sets': sets,
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
    int? sets,
  }) async {
    final res = await _dio.put<Map<String, Object?>>(
      '/exercise/sessions/$id',
      data: <String, Object?>{
        'type': type.name,
        'minutes': minutes,
        // 유형을 근력에서 바꾼 수정이면 null 을 실어 세트를 지운다 — 빼고
        // 보내면 옛 세트가 기록에 남는다.
        'sets': sets,
        'calories': calories,
        'intensity': intensity.name,
        'day_label': dayLabel,
      },
    );
    return ExerciseSession.fromJson(res.data!);
  }
}
