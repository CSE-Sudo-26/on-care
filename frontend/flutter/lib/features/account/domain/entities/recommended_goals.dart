/// 온보딩이 회원의 **나이·성별·키·체중**에서 뽑아 미리 채워 두는 권장 목표.
///
/// 목표 화면을 빈 칸으로 내밀면 처음 온 회원은 무엇을 적어야 하는지 알 수
/// 없다 — 대개 건너뛰고, 목표 없는 프로필로 홈·식단·운동 탭의 모든 진행
/// 막대가 기본값을 견주게 된다. 그래서 온보딩은 **읽고 고칠 수 있는 값**을
/// 미리 넣어 준다.
///
/// 숫자의 출처는 공개된 권고안이며, 온보딩 화면도 목표 칸 아래에 같은
/// 출처를 한 줄로 적는다.
///
///  * **에너지필요추정량(EER)** — 2020 한국인 영양소 섭취기준이 채택한
///    성인(19세 이상) 추정식. 성별·나이·키·체중과 신체활동단계별(PA) 계수로
///    하루 필요 열량을 낸다.
///  * **에너지적정비율(AMDR)** — 같은 기준의 탄수화물 55~65% · 단백질
///    7~20% · 지방 15~30%.
///  * **나트륨·당류** — WHO 성인 나트륨 2,000mg 미만, 자유당 총열량의 10%
///    미만 권고.
///  * **운동** — WHO 신체활동 지침(2020)의 주 150분 중강도 유산소와 주 2회
///    이상 근력. 앱이 유형별로 재는 단위(분·세트)로 옮긴 값이
///    [kDefaultExerciseLoadGoals] 다 — 운동 탭·MY 와 같은 상수를 쓴다.
///
/// 회원이 칸을 직접 고치면 그 칸은 더 이상 권장값이 아니다. 화면은 그때
/// `권장값으로 되돌리기` 를 띄워 언제든 이 값으로 돌아올 수 있게 한다.
library;

import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';

/// 권장값이 **어디서 나왔는지**. 화면 각주와 안내 문구가 이 값으로 갈린다.
enum RecommendationBasis {
  /// 1단계에서 받은 나이·성별·키·체중으로 계산했다.
  personalized,

  /// 기본 정보가 모자라 앱 기본값을 그대로 쓴다.
  fallback,
}

/// 온보딩 3·4단계가 미리 채우는 열 칸.
class RecommendedGoals {
  const RecommendedGoals({
    required this.basis,
    required this.dailyCalories,
    required this.dailySodiumMg,
    required this.dailySugarG,
    required this.dailyCarbsG,
    required this.dailyProteinG,
    required this.dailyFatG,
    required this.dailyBurnKcal,
    required this.weeklyCardioMinutes,
    required this.weeklyStrengthSets,
    required this.weeklyFlexibilityMinutes,
  });

  final RecommendationBasis basis;

  // 식단 — 하루 목표.
  final int dailyCalories;
  final int dailySodiumMg;
  final int dailySugarG;
  final int dailyCarbsG;
  final int dailyProteinG;
  final int dailyFatG;

  // 운동 — 소모는 하루, 유형별은 한 주다 (#1139).
  final int dailyBurnKcal;
  final int weeklyCardioMinutes;
  final int weeklyStrengthSets;
  final int weeklyFlexibilityMinutes;

  bool get isPersonalized => basis == RecommendationBasis.personalized;
}

/// 탄·단·지 1g 의 열량(kcal) — 식품 영양표시가 쓰는 Atwater 계수.
const int kKcalPerCarbG = 4;
const int kKcalPerProteinG = 4;
const int kKcalPerFatG = 9;

/// 2020 한국인 영양소 섭취기준의 에너지적정비율 안에서 고른 배분.
///
/// 범위는 탄수화물 55~65% · 단백질 7~20% · 지방 15~30% 이고, 셋의 합이 100%
/// 가 되도록 각 범위 안쪽 값을 고른다.
const double kRecommendedCarbShare = 0.55;
const double kRecommendedProteinShare = 0.20;
const double kRecommendedFatShare = 0.25;

/// WHO 권고 — 성인 하루 나트륨 2,000mg 미만.
const int kRecommendedSodiumMg = 2000;

/// WHO 권고 — 자유당은 총 섭취 열량의 10% 미만.
const double kRecommendedSugarShare = 0.10;

/// EER 추정식이 성립하는 나이대(성인). 이보다 어린 회원은 다른 식을 써야
/// 하므로 계산하지 않고 앱 기본값으로 물러선다.
const int kEerMinAgeYears = 19;

/// 계산 결과를 가둬 두는 범위. 키·체중을 잘못 적었을 때 화면에 세 자리
/// 넘게 벗어난 목표가 채워지는 것을 막는다.
const int kMinRecommendedCalories = 1200;
const int kMaxRecommendedCalories = 4000;

/// 신체활동단계별 계수(PA) — **저활동적**. 앱은 활동 수준을 따로 묻지 않고,
/// 만성질환 관리가 목적인 회원에게 가장 무난한 단계를 기본으로 둔다.
const double kPaLowActiveMale = 1.11;
const double kPaLowActiveFemale = 1.12;

/// 나이·성별·키·체중으로 권장 목표를 만든다.
///
/// 넷 중 하나라도 없거나 성인 범위를 벗어나면 [RecommendationBasis.fallback]
/// 로 앱 기본값을 돌려준다 — 모자란 값을 지어내 계산하면 회원은 자기 몸에
/// 맞춘 수치라고 읽는데 실제로는 아무 근거가 없다.
RecommendedGoals recommendedGoalsFor({
  int? ageYears,
  String? gender,
  double? heightCm,
  double? weightKg,
}) {
  final int? kcal = estimatedEnergyRequirement(
    ageYears: ageYears,
    gender: gender,
    heightCm: heightCm,
    weightKg: weightKg,
  );
  return recommendedGoalsFromCalories(
    kcal ?? UserProfile.defaultDailyCalories,
    basis: kcal == null
        ? RecommendationBasis.fallback
        : RecommendationBasis.personalized,
  );
}

/// 에너지필요추정량(kcal/일). 계산할 수 없으면 null.
///
/// 2020 한국인 영양소 섭취기준이 채택한 성인 추정식이다.
///
///   남자: 662 − 9.53 × 나이 + PA × (15.91 × 체중kg + 539.6 × 키m)
///   여자: 354 − 6.91 × 나이 + PA × (9.36 × 체중kg + 726 × 키m)
///
/// 성별을 `other` 로 골랐거나 비워 둔 회원은 두 식의 평균을 쓴다 — 한쪽
/// 식으로 몰아 두면 그 회원의 목표만 조용히 한 성별의 값이 된다.
int? estimatedEnergyRequirement({
  int? ageYears,
  String? gender,
  double? heightCm,
  double? weightKg,
}) {
  if (ageYears == null || heightCm == null || weightKg == null) return null;
  if (ageYears < kEerMinAgeYears || ageYears > 120) return null;
  if (heightCm < 50 || heightCm > 300) return null;
  if (weightKg < 20 || weightKg > 500) return null;

  final double heightM = heightCm / 100;
  final double male =
      662 -
      9.53 * ageYears +
      kPaLowActiveMale * (15.91 * weightKg + 539.6 * heightM);
  final double female =
      354 -
      6.91 * ageYears +
      kPaLowActiveFemale * (9.36 * weightKg + 726 * heightM);

  final double kcal = switch (gender) {
    'male' => male,
    'female' => female,
    _ => (male + female) / 2,
  };
  return kcal
      .round()
      .clamp(kMinRecommendedCalories, kMaxRecommendedCalories)
      .toInt();
}

/// 생년월일(`YYYY-MM-DD`) → 만 나이. 읽을 수 없으면 null.
int? ageFromBirthDate(String birthDate, {required DateTime today}) {
  final DateTime? birth = DateTime.tryParse(birthDate.trim());
  if (birth == null) return null;
  int age = today.year - birth.year;
  final bool beforeBirthday =
      today.month < birth.month ||
      (today.month == birth.month && today.day < birth.day);
  if (beforeBirthday) age -= 1;
  return age < 0 || age > 120 ? null : age;
}

/// 하루 열량에서 나머지 식단 목표를 뽑고, 운동 목표는 상수를 그대로 쓴다.
///
/// 회원이 칼로리 칸을 직접 고쳤을 때도 쓴다 — 그 뒤로 탄단지·당류의 권장값은
/// 추정식이 아니라 **회원이 적은 칼로리**를 나눈 값이어야 한다. 화면 각주가
/// 말하는 비율(탄 55% · 단 20% · 지 25%)과 칸의 숫자가 어긋나지 않는다.
RecommendedGoals recommendedGoalsFromCalories(
  int kcal, {
  required RecommendationBasis basis,
}) => RecommendedGoals(
  basis: basis,
  dailyCalories: kcal,
  dailySodiumMg: kRecommendedSodiumMg,
  dailySugarG: (kcal * kRecommendedSugarShare / kKcalPerCarbG).round(),
  dailyCarbsG: (kcal * kRecommendedCarbShare / kKcalPerCarbG).round(),
  dailyProteinG: (kcal * kRecommendedProteinShare / kKcalPerProteinG).round(),
  dailyFatG: (kcal * kRecommendedFatShare / kKcalPerFatG).round(),
  dailyBurnKcal: kDefaultExerciseLoadGoals.dailyBurnKcal.round(),
  weeklyCardioMinutes: kDefaultExerciseLoadGoals.weeklyCardioMinutes.round(),
  weeklyStrengthSets: kDefaultExerciseLoadGoals.weeklyStrengthSets.round(),
  weeklyFlexibilityMinutes: kDefaultExerciseLoadGoals.weeklyFlexibilityMinutes
      .round(),
);
