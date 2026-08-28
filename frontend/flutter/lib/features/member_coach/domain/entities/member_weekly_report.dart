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
    this.sodiumTarget,
    this.previous,
    this.asOf,
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

  /// 회원이 정해 둔 하루 나트륨 목표(mg). 트레이너 화면은 서버가 세어 준
  /// `나트륨 초과 일수` 를 읽지만, 회원 앱에는 그 값이 없고 대신 **회원 자신의
  /// 목표**가 있다 — 같은 지표를 자기 기준으로 다시 센다.
  final int? sodiumTarget;

  /// 이 문서를 세운 날. 그 주에서 **아직 오지 않은 요일**을 가리기 위해 든다 —
  /// 오지 않은 날을 `기록 없음` 이라고 적으면 지키지 못한 날처럼 읽힌다(#1613).
  final DateTime? asOf;

  /// [weekdayIndex] 요일이 아직 오지 않았는가. 세운 날을 모르면 늘 false 다.
  bool isUpcoming(int weekdayIndex) {
    final DateTime? today = asOf;
    if (today == null) return false;
    final DateTime day = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + weekdayIndex,
    );
    return day.isAfter(DateTime(today.year, today.month, today.day));
  }

  /// 바로 앞 주. 트레이너 화면의 첫 카드가 `지난주 대비` 비교라 문서도 그 자리를
  /// 갖는다. 앞 주의 앞 주까지는 세지 않으므로 이 값의 [previous] 는 늘 null 이다.
  final MemberWeeklyReport? previous;

  /// 같은 주에 [previous] 만 갈아 끼운다. 앞 주 자신은 비교 상대를 갖지 않는다.
  MemberWeeklyReport copyWithPrevious(MemberWeeklyReport? last) =>
      MemberWeeklyReport(
        weekStart: weekStart,
        exercise: exercise,
        diet: diet,
        sessionsBooked: sessionsBooked,
        sessionsDone: sessionsDone,
        sodiumTarget: sodiumTarget,
        previous: last,
        asOf: asOf,
      );

  /// 식단을 기록한 날 수.
  int get loggedDays => diet.loggedDays;

  /// 하루 나트륨 목표를 넘긴 날 수. 목표를 모르면 null 이다 — 기준 없이 센
  /// `초과 3일` 은 무엇을 넘었다는 말인지 알 수 없다.
  int? get sodiumOverDays {
    final int? target = sodiumTarget;
    if (target == null) return null;
    return diet.logged.where((DietPeriodDay d) => d.sodiumMg > target).length;
  }

  /// 기록한 날의 평균 탄·단·지(g). 기록이 없으면 null 이다.
  double? get avgCarbsG => _loggedMean((DietPeriodDay d) => d.carbsG);
  double? get avgProteinG => _loggedMean((DietPeriodDay d) => d.proteinG);
  double? get avgFatG => _loggedMean((DietPeriodDay d) => d.fatG);

  double? _loggedMean(double Function(DietPeriodDay day) pick) {
    final List<DietPeriodDay> days = diet.logged;
    if (days.isEmpty) return null;
    return days.fold<double>(
          0,
          (double sum, DietPeriodDay d) => sum + pick(d),
        ) /
        days.length;
  }

  /// 리포트가 가리키는 주의 일요일.
  DateTime get weekEnd =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

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
  ///
  /// 이름은 [ExerciseSession.items] 를 먼저 본다. 두 경로가 이름을 담는 자리가
  /// 다르기 때문이다 — 실 API·drift 는 그날 그 종류의 운동을 `name` 한 줄로 이어
  /// 붙이고 `items` 에도 그 한 줄을 담지만, 데모 경로는 `items` 에 운동을 하나씩
  /// 담고 `name` 을 비워 둔다. `name` 만 읽으면 데모에서 이름이 전부 걸러져,
  /// 5일을 운동한 주의 요일별 상세가 이레 내내 `기록 없음` 이 됐다(#1617).
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
        .expand(
          (ExerciseSession s) =>
              s.items.isNotEmpty ? s.items : <String>[s.name],
        )
        .map((String name) => name.trim())
        .where((String name) => name.isNotEmpty)
        .toList(growable: false);
  }
}
