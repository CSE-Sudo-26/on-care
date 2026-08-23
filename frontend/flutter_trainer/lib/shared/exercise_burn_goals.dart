/// 운동 그래프가 쓰는 **지표 정의**. 회원 앱
/// `features/exercise/domain/entities/exercise_load.dart` 와 같은 규칙을 여기에도
/// 적어 둔다 — 두 앱은 패키지가 갈라져 있어 코드를 공유할 수 없다
/// (`activity_charts`·`metric_trend_chart` 와 같은 방식이다).
///
/// 한쪽만 고치면 같은 회원의 같은 주가 회원 화면과 트레이너 화면에서 다른
/// 이야기를 한다. 값을 바꿀 일이 생기면 **양쪽을 함께** 고친다.
library;

/// 유형별로 재는 단위가 다르다.
///
///   * 유산소  → **분**
///   * 근력    → **세트**
///   * 스트레칭 → **분**
///
/// 서로 더할 수 없는 값이라, 높이를 비교해야 하는 자리(도넛·막대)에서는 셋이
/// 함께 만든 결과인 **소모 칼로리**를 쓴다.
enum ExerciseKind { cardio, strength, stretching }

/// 근력 1세트가 차지하는 **벽시계 시간**(세트 + 휴식). 세트 수를 따로 기록하지
/// 않는 응답(분만 있는 기록)을 세트로 되돌릴 때 쓰는 다리다.
const double kStrengthMinutesPerSet = 3;

/// 분만 남은 근력 기록 → 세트 수(대략). 45분 ≈ 15세트.
int setsFromStrengthMinutes(num minutes) =>
    (minutes / kStrengthMinutesPerSet).round();

/// 하루 소모 칼로리 목표.
///
/// 고혈압·당뇨 관리가 목적인 회원이 **매일** 닿을 수 있는 선으로 잡는다.
/// 500kcal(MY 기본값)은 하루 한 시간 넘게 움직여야 나오는 수라, 꾸준히 한
/// 주에도 목표선을 한 번도 못 넘어 그래프가 늘 '실패' 로만 읽혔다.
const double kDailyBurnKcal = 300;

/// 주간 소모 칼로리 목표 — 하루 목표 × 7.
const double kWeeklyBurnKcal = kDailyBurnKcal * 7;

/// 주간 유산소 목표(분). WHO 의 주 150분 중강도 권고.
const double kWeeklyCardioMinutes = 150;

/// 주간 근력 목표(세트). 하루 3세트 × 7일.
const double kWeeklyStrengthSets = 21;

/// 주간 스트레칭 목표(분).
const double kWeeklyStretchingMinutes = 60;

/// 유형의 주간 목표를 **그 유형의 단위**로.
double weeklyGoalOf(ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => kWeeklyCardioMinutes,
  ExerciseKind.strength => kWeeklyStrengthSets,
  ExerciseKind.stretching => kWeeklyStretchingMinutes,
};
