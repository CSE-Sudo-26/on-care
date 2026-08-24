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
  ///
  /// [sets] 는 근력 기록에만 있는 값이다 — 근력은 시간이 아니라 세트로 읽는
  /// 운동이라 회원이 적은 수를 그대로 싣는다. 다른 유형은 null 이고, 서버도
  /// 근력이 아닌 기록에서는 이 값을 버린다. (#1262)
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    int? sets,
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
    int? sets,
  });
}
