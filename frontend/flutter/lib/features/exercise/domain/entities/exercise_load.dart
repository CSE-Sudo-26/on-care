import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

/// 운동 유형마다 **재는 단위가 다르다**는 사실을 그대로 인정하는 모델.
///
/// 예전 `운동 현황` 그래프는 모든 유형을 `분` 으로 쌓았다. 유산소는 시간이
/// 곧 운동량이지만, 근력은 그렇지 않다 — 같은 40분이라도 12세트를 한 날과
/// 6세트를 하고 절반을 쉰 날이 같은 막대가 됐다. 그래서 여기서는
///
///   * 유산소  → **분**
///   * 근력    → **세트**
///   * 유연성  → **분**
///
/// 을 각자의 단위로 들고 다니고, 한 축에서 비교해야 할 때만 [ExerciseDayLoad.score]
/// 로 환산한다. 화면의 숫자·목표는 언제나 원래 단위로 보여 준다.
enum ExerciseLoadKind { cardio, strength, flexibility }

/// 환산 축 = **MET·분**(대사당량 × 시간). WHO·ACSM 의 신체활동 권고가 쓰는
/// 단위라서, "주 150분 중강도" 같은 실제 가이드라인을 그대로 목표로 옮길 수
/// 있다. 유산소는 6.0(중강도), 근력은 5.0, 유연성은 2.5 MET 로 본다.
const double kMetCardio = 6.0;
const double kMetStrength = 5.0;
const double kMetFlexibility = 2.5;

/// 근력 **1세트의 유효 운동 시간**. 세트 사이 휴식은 부하가 아니므로 뺀다 —
/// 근력을 시간으로 재면 안 되는 이유가 바로 이 휴식이다.
const double kStrengthMinutesPerSet = 1.5;

/// 근력 1세트가 차지하는 **벽시계 시간**(세트 + 휴식). 세트 수를 따로 기록하지
/// 않는 옛 기록(분만 있는 기록)을 세트로 되돌릴 때만 쓰는 다리다. 세션에
/// 세트·반복·중량이 저장되면 이 환산은 필요 없어진다.
const double kStrengthMinutesPerSetWithRest = 3.0;

/// 세트 하나의 활동량(MET·분) = 1.5분 × 5.0 MET = 7.5.
double strengthScoreOfSets(num sets) =>
    sets * kStrengthMinutesPerSet * kMetStrength;

/// 세트를 **모르는** 옛 기록에서만 쓰는 환산. 45분 ≈ 15세트.
///
/// 기록이 세트를 들고 있으면 언제나 그 값을 쓴다 — 분에서 되짚어 계산하면
/// 트레이너가 보낸 프로그램의 세트 수와 화면의 수가 어긋난다.
int setsFromStrengthMinutes(double minutes) =>
    (minutes / kStrengthMinutesPerSetWithRest).round();

/// 유형별 목표. **주간 목표가 원본**이고, 하루 목표는 그 유형을 주 몇 번 하는지로
/// 나눈 값이다 — 근력은 매일 하는 운동이 아니라서 주간 목표를 7 로 나누면
/// (2.3세트) 아무 뜻이 없는 숫자가 된다.
class ExerciseLoadGoals {
  const ExerciseLoadGoals({
    // 고혈압·당뇨 관리가 목적인 회원이 **매일** 닿을 수 있는 선으로 잡는다.
    // 500kcal(MY 기본값)은 하루 한 시간 넘게 움직여야 나오는 수라, 꾸준히 한
    // 주에도 목표선을 한 번도 못 넘어 그래프가 늘 '실패' 로만 읽혔다.
    this.dailyBurnKcal = 300,
    this.weeklyCardioMinutes = 150, // WHO: 주 150분 중강도 유산소
    this.weeklyStrengthSets = 21, // 하루 3세트 × 7일
    this.weeklyFlexibilityMinutes = 60,
    this.cardioDaysPerWeek = 5,
    this.strengthDaysPerWeek = 7,
    this.flexibilityDaysPerWeek = 6,
  });

  /// 하루 소모 칼로리 목표. 오늘 도넛이 이 값을 채운다.
  final double dailyBurnKcal;

  /// 주간 소모 칼로리 목표 — 하루 목표 × 7.
  double get weeklyBurnKcal => dailyBurnKcal * 7;

  final double weeklyCardioMinutes;
  final double weeklyStrengthSets;
  final double weeklyFlexibilityMinutes;
  final int cardioDaysPerWeek;
  final int strengthDaysPerWeek;
  final int flexibilityDaysPerWeek;

  double get dailyCardioMinutes => weeklyCardioMinutes / cardioDaysPerWeek;
  double get dailyStrengthSets => weeklyStrengthSets / strengthDaysPerWeek;
  double get dailyFlexibilityMinutes =>
      weeklyFlexibilityMinutes / flexibilityDaysPerWeek;

  double goalOf(ExerciseLoadKind kind) => switch (kind) {
    ExerciseLoadKind.cardio => dailyCardioMinutes,
    ExerciseLoadKind.strength => dailyStrengthSets,
    ExerciseLoadKind.flexibility => dailyFlexibilityMinutes,
  };

  double weeklyGoalOf(ExerciseLoadKind kind) => switch (kind) {
    ExerciseLoadKind.cardio => weeklyCardioMinutes,
    ExerciseLoadKind.strength => weeklyStrengthSets,
    ExerciseLoadKind.flexibility => weeklyFlexibilityMinutes,
  };

  /// 세 유형의 주간 목표를 합친 활동량(MET·분). WHO 최소 권고(600)의 두 배
  /// 가까운, "권고를 넉넉히 채운 한 주" 다.
  double get weeklyScore =>
      weeklyCardioMinutes * kMetCardio +
      strengthScoreOfSets(weeklyStrengthSets) +
      weeklyFlexibilityMinutes * kMetFlexibility;

  /// 하루 평균 목표. 주간 목표를 7 로 나눈 값 — 요일 막대의 기준선이다.
  double get dailyScore => weeklyScore / 7;
}

const ExerciseLoadGoals kDefaultExerciseLoadGoals = ExerciseLoadGoals();

/// 하루치 운동을 **유형별 원래 단위**로 담는다.
class ExerciseDayLoad {
  const ExerciseDayLoad({
    required this.date,
    this.cardioMinutes = 0,
    this.strengthSets = 0,
    this.flexibilityMinutes = 0,
    this.otherMinutes = 0,
    this.calories = 0,
  });

  /// 유형별 `분` 만 있는 기록에서 만든다. 근력의 분은 세트로 되돌린다.
  factory ExerciseDayLoad.fromMinutes({
    required DateTime date,
    required double cardio,
    required double strength,
    required double flexibility,
    double other = 0,
    double calories = 0,
    double? sets,
  }) => ExerciseDayLoad(
    date: date,
    cardioMinutes: cardio,
    // 기록한 세트가 있으면 그 값이다. 없을 때만 분에서 환산한다.
    strengthSets: (sets ?? setsFromStrengthMinutes(strength)).round(),
    flexibilityMinutes: flexibility,
    otherMinutes: other,
    calories: calories,
  );

  final DateTime date;
  final double cardioMinutes;
  final int strengthSets;
  final double flexibilityMinutes;

  /// 목표가 없는 나머지 운동(기타). **활동량 점수에 넣지 않는다** — 그래프에
  /// 그리지 않기로 한 값이 숫자에만 섞여 들면 머리의 합계와 막대가 어긋난다.
  /// 화면에는 분 수만 따로 적는다.
  final double otherMinutes;

  /// 그날 태운 칼로리. 유형별 단위가 제각각인 운동을 **하나의 축**으로 보는
  /// 자리다 — 도넛과 막대는 이 값을 그린다.
  final double calories;

  double get cardioScore => cardioMinutes * kMetCardio;
  double get strengthScore => strengthScoreOfSets(strengthSets);
  double get flexibilityScore => flexibilityMinutes * kMetFlexibility;

  /// 한 축에서 비교하기 위한 하루 활동량(MET·분).
  double get score => cardioScore + strengthScore + flexibilityScore;

  bool get isActive => score > 0 || otherMinutes > 0 || calories > 0;

  double valueOf(ExerciseLoadKind kind) => switch (kind) {
    ExerciseLoadKind.cardio => cardioMinutes,
    ExerciseLoadKind.strength => strengthSets.toDouble(),
    ExerciseLoadKind.flexibility => flexibilityMinutes,
  };

  double scoreOf(ExerciseLoadKind kind) => switch (kind) {
    ExerciseLoadKind.cardio => cardioScore,
    ExerciseLoadKind.strength => strengthScore,
    ExerciseLoadKind.flexibility => flexibilityScore,
  };
}

/// 주간 기록 → 요일별 [ExerciseDayLoad]. [monday] 는 그 주의 월요일.
///
/// 유형별 시리즈가 없는(옛) 페이로드는 전부 유산소로 본다 — 없는 근력 세트를
/// 지어내는 것보다 낫다.
List<ExerciseDayLoad> dayLoadsOfWeek(ExerciseWeek week, DateTime monday) {
  final int n = week.dailyMinutes.length;
  final bool hasBreakdown =
      n > 0 &&
      week.cardioMinutes.length == n &&
      week.strengthMinutes.length == n &&
      week.stretchingMinutes.length == n;
  return <ExerciseDayLoad>[
    for (int i = 0; i < n; i++)
      ExerciseDayLoad.fromMinutes(
        date: DateTime(monday.year, monday.month, monday.day + i),
        cardio: hasBreakdown ? week.cardioMinutes[i] : week.dailyMinutes[i],
        strength: hasBreakdown ? week.strengthMinutes[i] : 0,
        flexibility: hasBreakdown ? week.stretchingMinutes[i] : 0,
        other: i < week.otherMinutes.length ? week.otherMinutes[i] : 0,
        calories: i < week.dailyCalories.length ? week.dailyCalories[i] : 0,
        sets: i < week.strengthSets.length ? week.strengthSets[i] : null,
      ),
  ];
}

/// 활동한 날의 **최장 연속 구간**. 요일 배열이 아니라 날짜 순서의 목록을 본다.
int longestActiveStreakOfLoads(List<ExerciseDayLoad> loads) =>
    longestActiveStreak(<double>[
      for (final ExerciseDayLoad d in loads) d.score + d.otherMinutes,
    ]);
