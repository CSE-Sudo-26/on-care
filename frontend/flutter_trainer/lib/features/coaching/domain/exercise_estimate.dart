import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';

/// 유형·시간·강도로 소모 칼로리를 어림한다.
///
/// 백엔드 `exercise_service.estimate_calories` 와 같은 표다(#1276). 트레이너가
/// 프로그램을 짜는 동안 화면이 보여 주는 값과 회원이 그 운동을 마친 뒤 기록에
/// 남는 값이 갈리면, 같은 운동을 두 사람이 다른 수로 이야기하게 된다.
///
/// **세 유형을 한 축에서 비교하는 값은 이 칼로리 하나다.** 유산소는 분, 근력은
/// 세트, 스트레칭은 분으로 재는 서로 더할 수 없는 값이라, 합쳐 보려면 셋이 함께
/// 만든 결과 하나로 읽어야 한다.
const Map<String, double> _kcalPerMinute = <String, double>{
  '유산소': 9,
  '근력': 6,
  '스트레칭': 3,
  '기타': 5,
};

const Map<String, double> _intensityFactor = <String, double>{
  'light': 0.85,
  'moderate': 1.0,
  'high': 1.2,
};

/// 근력 1세트가 차지하는 벽시계 시간(세트 + 휴식). 회원 앱
/// `kStrengthMinutesPerSetWithRest`·백엔드 `STRENGTH_MINUTES_PER_SET` 과 같은
/// 값이라야 세 곳이 같은 분을 센다.
const double kStrengthMinutesPerSet = 3;

/// 근력 세트 수 → 분. 서버는 여전히 분(>0)을 요구하고 주간 운동 시간도 분으로
/// 세므로, 세트로 받은 값을 저장 전에 여기서 환산한다.
int minutesFromSets(int sets) => (sets * kStrengthMinutesPerSet).round();

/// 이 운동의 예상 소모 칼로리. [minutes] 는 근력이면 [minutesFromSets] 로
/// 환산한 값이다 — 중량은 계산에 쓰지 않는다(같은 무게라도 사람마다 소모가
/// 달라, 추정식에 넣으면 근거 없는 정밀도가 된다).
int estimateRoutineCalories({
  required String type,
  required int minutes,
  required String intensity,
}) {
  final double perMinute = _kcalPerMinute[normaliseRoutineType(type)] ?? 5;
  final double factor =
      _intensityFactor[normaliseRoutineIntensity(intensity)] ?? 1.0;
  return (perMinute * (minutes < 0 ? 0 : minutes) * factor).round();
}
