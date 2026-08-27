import 'package:oncare/features/diet/domain/entities/diet_period.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

/// 트레이너가 보낸 주간 리포트를 회원 쪽에서 다시 세운 것. (#1600)
///
/// 트레이너 앱의 `WeeklyReport` 와 같은 것을 본다 — 그 주의 운동·식단·PT. 다만
/// 출처가 다르다. 트레이너 화면은 서버가 회원 기록을 모아 준 값을 읽고, 여기서는
/// 회원 앱이 이미 들고 있는 자기 기록을 접는다. 리포트에 첨부된 PDF 가 있으면
/// 그 파일이 먼저다 — 이 값은 **열 파일이 없을 때** 같은 통계를 보여 주기 위한
/// 것이다(데모·본문만 보낸 리포트).
class MemberWeeklyReport {
  /// Creates a report for the week beginning [weekStart].
  const MemberWeeklyReport({
    required this.weekStart,
    required this.exercise,
    required this.diet,
    required this.sessionsBooked,
    required this.sessionsDone,
  });

  /// 리포트가 가리키는 주의 월요일.
  final DateTime weekStart;

  /// 그 주의 운동 기록.
  final ExerciseWeek exercise;

  /// 그 주의 식단 집계(월→일 일곱 칸).
  final DietPeriod diet;

  /// 그 주에 잡혀 있던 PT.
  final int sessionsBooked;

  /// 그중 진행된 PT.
  final int sessionsDone;

  /// 리포트가 가리키는 주의 일요일.
  DateTime get weekEnd => DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day + 6,
  );

  /// 운동한 날 수.
  int get workoutDays => exercise.workoutCount;

  /// 요일별 운동 시간(분). 일곱 칸이 아니면 추이를 그리지 않는다.
  List<double> get minutesByDay => exercise.dailyMinutes;

  /// 요일별 섭취 칼로리.
  List<int> get caloriesByDay =>
      diet.days.map((DietPeriodDay d) => d.calories).toList(growable: false);

  /// 요일별 나트륨(mg).
  List<int> get sodiumByDay =>
      diet.days.map((DietPeriodDay d) => d.sodiumMg).toList(growable: false);

  /// 요일별 당류(g).
  List<double> get sugarByDay =>
      diet.days.map((DietPeriodDay d) => d.sugarG).toList(growable: false);

  /// 그 요일에 한 운동 이름들. 기록이 없으면 빈 목록이다.
  ///
  /// 세션은 요일 표시(`dayLabel`)를 들고 있다 — 날짜가 비어 있는 경로(데모)도
  /// 있어서, 날짜가 있으면 날짜로 판정하고 없으면 표시를 쓴다.
  List<String> exercisesOn(int weekdayIndex, List<String> weekdayLabels) {
    final DateTime day = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + weekdayIndex,
    );
    final String label = weekdayIndex < weekdayLabels.length
        ? weekdayLabels[weekdayIndex]
        : '';
    return exercise.sessions
        .where((ExerciseSession s) {
          final DateTime? date = s.date;
          if (date != null) {
            final DateTime local = date.toLocal();
            return local.year == day.year &&
                local.month == day.month &&
                local.day == day.day;
          }
          return label.isNotEmpty && s.dayLabel == label;
        })
        .map((ExerciseSession s) => s.name)
        .where((String name) => name.trim().isNotEmpty)
        .toList(growable: false);
  }
}
