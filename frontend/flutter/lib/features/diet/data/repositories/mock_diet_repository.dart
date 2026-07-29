import 'dart:typed_data';

import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';

class MockDietRepository implements DietRepository {
  const MockDietRepository();

  @override
  Future<DietAnalysisResult> analyze({
    required Uint8List imageBytes,
    required String filename,
    required String mealType,
    String? idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const DietAnalysisResult(
      entryId: 'mock',
      foods: <RecognizedFood>[
        RecognizedFood(
          name: '비빔밥',
          calories: 600,
          sodiumMg: 900,
          sugarG: 8,
          source: 'db',
        ),
        RecognizedFood(
          name: '김치',
          calories: 15,
          sodiumMg: 300,
          sugarG: 1,
          source: 'db',
        ),
      ],
      totalCalories: 615,
      totalSodiumMg: 1200,
      totalSugarG: 9,
      coachComment: '비빔밥은 채소가 풍부해 좋아요. 나트륨이 다소 높으니 장을 줄여보세요.',
    );
  }

  @override
  Future<DietDay> fetchToday() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    // Per-food nutrition is the single source of truth: the diet-tab meal
    // cards and the "오늘의 영양 요약" totals are both derived from these foods,
    // so the numbers always agree (아침 217/221/6.3 + 점심 750/3,200/8.5 =
    // 967/3,421/14.8).
    return const DietDay(
      entries: <DietEntry>[
        DietEntry(
          id: 'mock-breakfast',
          mealType: MealType.breakfast,
          timeLabel: '08:20',
          totalCalories: 217,
          sodiumMg: 221,
          sugarG: 6.3,
          photoAsset: 'assets/images/breakfast-scrambled-egg-strawberry.jpg',
          aiComment: '단백질과 식이섬유의 깔끔한 조합으로, 소금 간과 기름만 조절하면 혈당과 혈압 모두 잡는 우수한 식단입니다.',
          foods: <FoodItem>[
            FoodItem(
              name: '스크램블 에그',
              calories: 185,
              sodiumMg: 220,
              sugarG: 0.8,
            ),
            FoodItem(name: '딸기', calories: 32, sodiumMg: 1, sugarG: 5.5),
          ],
        ),
        DietEntry(
          id: 'mock-lunch',
          mealType: MealType.lunch,
          timeLabel: '12:40',
          totalCalories: 750,
          sodiumMg: 3200,
          sugarG: 8.5,
          photoAsset: 'assets/images/lunch-jjamppong.jpg',
          aiComment: '정제 면과 높은 나트륨으로 혈압·혈당 부담이 매우 크니, 국물은 남기고 해물과 야채 위주로 드시는 것이 좋습니다.',
          foods: <FoodItem>[
            FoodItem(
              name: '짬뽕',
              calories: 750,
              sodiumMg: 3200,
              sugarG: 8.5,
            ),
          ],
        ),
      ],
      totalCalories: 967,
      totalSodiumMg: 3421,
      totalSugarG: 14.8,
      macros: DietMacros(carbsPct: 50, proteinPct: 30, fatPct: 20),
      aiCoachMessage:
          '점심 짬뽕으로 나트륨과 혈당 부담이 크게 높아졌어요! 오늘 저녁은 간을 하지 않은 두부/닭가슴살 샐러드나 채소 위주 식단으로 가볍게 드시고, 물을 자주 드셔주세요.',
    );
  }

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<DietEntry> updateEntry({
    required String id,
    String? mealType,
    String? timeLabel,
    List<FoodItem>? foods,
    int? totalCalories,
    int? sodiumMg,
    double? sugarG,
  }) async {
    final updatedFoods = foods ?? const <FoodItem>[];
    return DietEntry(
      id: id,
      mealType: mealType != null
          ? MealType.values.byName(mealType)
          : MealType.lunch,
      timeLabel: timeLabel ?? '',
      totalCalories:
          totalCalories ??
          updatedFoods.fold<int>(0, (sum, food) => sum + food.calories),
      sodiumMg: sodiumMg ?? 0,
      sugarG: sugarG ?? 0,
      foods: updatedFoods,
    );
  }
}
