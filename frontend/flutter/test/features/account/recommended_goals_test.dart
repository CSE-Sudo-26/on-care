import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/domain/entities/recommended_goals.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';

/// 온보딩이 미리 채우는 권장 목표의 계산. (#1276 후속 — 온보딩 개편)
///
/// 화면이 "나이·성별·키·체중으로 계산한 값" 이라고 말하므로, 그 말이 참인지를
/// 여기서 못 박는다.
void main() {
  group('에너지필요추정량(EER)', () {
    test('성인 남성은 2020 한국인 영양소 섭취기준 추정식을 그대로 쓴다', () {
      // 662 − 9.53×35 + 1.11×(15.91×70 + 539.6×1.75) = 2,612.83
      expect(
        estimatedEnergyRequirement(
          ageYears: 35,
          gender: 'male',
          heightCm: 175,
          weightKg: 70,
        ),
        2613,
      );
    });

    test('성인 여성은 여성 식을 쓴다', () {
      // 354 − 6.91×35 + 1.12×(9.36×55 + 726×1.60) = 1,989.72
      expect(
        estimatedEnergyRequirement(
          ageYears: 35,
          gender: 'female',
          heightCm: 160,
          weightKg: 55,
        ),
        1990,
      );
    });

    test('성별을 고르지 않았거나 기타면 두 식의 평균이다', () {
      final int? male = estimatedEnergyRequirement(
        ageYears: 35,
        gender: 'male',
        heightCm: 170,
        weightKg: 65,
      );
      final int? female = estimatedEnergyRequirement(
        ageYears: 35,
        gender: 'female',
        heightCm: 170,
        weightKg: 65,
      );
      final int? other = estimatedEnergyRequirement(
        ageYears: 35,
        gender: 'other',
        heightCm: 170,
        weightKg: 65,
      );
      expect(other, isNotNull);
      expect(other, greaterThan(female!));
      expect(other, lessThan(male!));
      // 한쪽 성별로 몰아 두면 그 회원의 목표만 조용히 한 성별 값이 된다.
      // 각 칸을 따로 반올림한 뒤 평균 낸 값과는 1kcal 어긋날 수 있다.
      expect(other, closeTo((male + female) / 2, 1));
    });

    test('나이가 많을수록 낮아진다', () {
      final int? young = estimatedEnergyRequirement(
        ageYears: 25,
        gender: 'male',
        heightCm: 175,
        weightKg: 70,
      );
      final int? old = estimatedEnergyRequirement(
        ageYears: 65,
        gender: 'male',
        heightCm: 175,
        weightKg: 70,
      );
      expect(old, lessThan(young!));
    });

    test('넷 중 하나라도 없으면 계산하지 않는다', () {
      expect(
        estimatedEnergyRequirement(
          gender: 'male',
          heightCm: 175,
          weightKg: 70,
        ),
        isNull,
      );
      expect(
        estimatedEnergyRequirement(
          ageYears: 35,
          gender: 'male',
          weightKg: 70,
        ),
        isNull,
      );
    });

    test('성인 추정식이므로 미성년은 계산하지 않는다', () {
      expect(
        estimatedEnergyRequirement(
          ageYears: 15,
          gender: 'male',
          heightCm: 170,
          weightKg: 60,
        ),
        isNull,
      );
    });

    test('키·체중이 범위를 벗어나면 계산하지 않는다', () {
      expect(
        estimatedEnergyRequirement(
          ageYears: 35,
          gender: 'male',
          heightCm: 5,
          weightKg: 70,
        ),
        isNull,
      );
      expect(
        estimatedEnergyRequirement(
          ageYears: 35,
          gender: 'male',
          heightCm: 175,
          weightKg: 900,
        ),
        isNull,
      );
    });

    test('결과는 사람이 먹을 수 있는 범위 안에 머문다', () {
      final int? tiny = estimatedEnergyRequirement(
        ageYears: 100,
        gender: 'female',
        heightCm: 130,
        weightKg: 25,
      );
      expect(tiny, greaterThanOrEqualTo(kMinRecommendedCalories));
      final int? huge = estimatedEnergyRequirement(
        ageYears: 19,
        gender: 'male',
        heightCm: 250,
        weightKg: 400,
      );
      expect(huge, lessThanOrEqualTo(kMaxRecommendedCalories));
    });
  });

  group('권장 목표', () {
    test('탄단지는 칼로리를 에너지적정비율로 나눈 값이다', () {
      final RecommendedGoals r = recommendedGoalsFromCalories(
        2000,
        basis: RecommendationBasis.personalized,
      );
      expect(r.dailyCalories, 2000);
      expect(r.dailyCarbsG, 275); // 2000×0.55 / 4
      expect(r.dailyProteinG, 100); // 2000×0.20 / 4
      expect(r.dailyFatG, 56); // 2000×0.25 / 9
    });

    test('세 비율의 합은 100% 이고 각자 기준 범위 안에 있다', () {
      // 2020 한국인 영양소 섭취기준: 탄 55~65 · 단 7~20 · 지 15~30.
      expect(
        kRecommendedCarbShare +
            kRecommendedProteinShare +
            kRecommendedFatShare,
        closeTo(1.0, 1e-9),
      );
      expect(kRecommendedCarbShare, inInclusiveRange(0.55, 0.65));
      expect(kRecommendedProteinShare, inInclusiveRange(0.07, 0.20));
      expect(kRecommendedFatShare, inInclusiveRange(0.15, 0.30));
    });

    test('당류는 총 열량의 10%, 나트륨은 몸과 무관한 고정값이다', () {
      final RecommendedGoals r = recommendedGoalsFromCalories(
        2400,
        basis: RecommendationBasis.personalized,
      );
      expect(r.dailySugarG, 60); // 2400×0.10 / 4
      expect(r.dailySodiumMg, kRecommendedSodiumMg);
      expect(kRecommendedSodiumMg, 2000); // WHO 권고
    });

    test('운동 권장값은 운동 탭·MY 가 쓰는 상수와 같은 값이다', () {
      final RecommendedGoals r = recommendedGoalsFor(
        ageYears: 35,
        gender: 'male',
        heightCm: 175,
        weightKg: 70,
      );
      expect(r.dailyBurnKcal, kDefaultExerciseLoadGoals.dailyBurnKcal.round());
      expect(r.weeklyCardioMinutes, 150); // WHO: 주 150분 중강도 유산소
      expect(
        r.weeklyStrengthSets,
        kDefaultExerciseLoadGoals.weeklyStrengthSets.round(),
      );
      expect(
        r.weeklyFlexibilityMinutes,
        kDefaultExerciseLoadGoals.weeklyFlexibilityMinutes.round(),
      );
    });

    test('기본 정보가 모자라면 앱 기본값으로 물러서고 그렇다고 밝힌다', () {
      final RecommendedGoals r = recommendedGoalsFor(gender: 'male');
      expect(r.basis, RecommendationBasis.fallback);
      expect(r.isPersonalized, isFalse);
      expect(r.dailyCalories, UserProfile.defaultDailyCalories);
    });

    test('기본 정보가 다 있으면 계산한 값이라고 밝힌다', () {
      final RecommendedGoals r = recommendedGoalsFor(
        ageYears: 35,
        gender: 'male',
        heightCm: 175,
        weightKg: 70,
      );
      expect(r.basis, RecommendationBasis.personalized);
      expect(r.dailyCalories, 2613);
    });
  });

  group('만 나이', () {
    test('생일이 지나지 않았으면 한 살 적다', () {
      expect(
        ageFromBirthDate('1990-07-15', today: DateTime(2026, 8, 24)),
        36,
      );
      expect(
        ageFromBirthDate('1990-09-15', today: DateTime(2026, 8, 24)),
        35,
      );
    });

    test('읽을 수 없는 값은 null 이다', () {
      expect(ageFromBirthDate('', today: DateTime(2026, 8, 24)), isNull);
      expect(ageFromBirthDate('언젠가', today: DateTime(2026, 8, 24)), isNull);
    });
  });
}
