import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

abstract class ExerciseRepository {
  Future<ExerciseWeek> fetchThisWeek();

  /// 한 주의 기록. [weekStart] 는 그 주의 **월요일**이다.
  ///
  /// 조회가 이번 주 하나뿐이라 운동 탭에서 지난 날짜를 골라도 보여줄 것이
  /// 없었다(#671). 이번 주를 넘겨 부르면 [fetchThisWeek] 과 같은 결과다.
  Future<ExerciseWeek> fetchWeek(DateTime weekStart);

  /// Persist a new workout session (POST /exercise/sessions) and return
  /// the created session as the server materialised it.
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  });

  /// DELETE /exercise/sessions/{id} — remove a workout session.
  Future<void> deleteSession(String id);

  /// PUT /exercise/sessions/{id} — edit a workout session.
  Future<ExerciseSession> updateSession({
    required String id,
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  });
}
