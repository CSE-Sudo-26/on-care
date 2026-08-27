import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

abstract class ExerciseRepository {
  Future<ExerciseWeek> fetchThisWeek();

  /// 한 주의 기록. [weekStart] 는 그 주의 **월요일**이다.
  ///
  /// 조회가 이번 주 하나뿐이라 운동 탭에서 지난 날짜를 골라도 보여줄 것이
  /// 없었다(#671). 이번 주를 넘겨 부르면 [fetchThisWeek] 과 같은 결과다.
  Future<ExerciseWeek> fetchWeek(DateTime weekStart);

  /// 기간에 맞는 운동 조언 — GET /exercise/advice. (#1574)
  ///
  /// [period] 는 화면의 기간 토글과 같은 말이다(`today`·`week`·`all`). 구간
  /// 경계는 서버가 정한다 — 앱이 따로 계산해 넘기면 같은 회원의 `이번 주` 가
  /// 화면마다 다른 날부터 시작한다.
  Future<String> fetchAdvice(String period);

  /// Persist a new workout session (POST /exercise/sessions) and return
  /// the created session as the server materialised it.
  ///
  /// [sets]·[reps]·[weight] 는 근력 기록에만 있는 값이다 — 근력은 시간이
  /// 아니라 세트·횟수·무게로 읽는 운동이라 회원이 적은 수를 그대로 싣는다.
  /// 다른 유형은 null 이고, 서버도 근력이 아닌 기록에서는 이 값들을 버린다.
  /// (#1262, #1276, #1310)
  ///
  /// [date] 는 회원이 달력에서 고른 날이다. 생략하면 서버가 오늘로 둔다.
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required DateTime date,
    String name = '',
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    int? sets,
    int? reps,
    double? weight,
  });

  /// DELETE /exercise/sessions/{id} — remove a workout session.
  Future<void> deleteSession(String id);

  /// PUT /exercise/sessions/{id} — edit a workout session.
  Future<ExerciseSession> updateSession({
    required String id,
    required ExerciseType type,
    required int minutes,
    required int calories,
    required DateTime date,
    String name = '',
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    int? sets,
    int? reps,
    double? weight,
  });
}
