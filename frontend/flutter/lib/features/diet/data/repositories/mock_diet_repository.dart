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
    return const DietDay(
      entries: <DietEntry>[
        DietEntry(
          id: 'mock-breakfast',
          mealType: MealType.breakfast,
          timeLabel: '08:20',
          totalCalories: 315,
          sodiumMg: 380,
          sugarG: 18,
          foods: <FoodItem>[
            FoodItem(name: '오트밀', calories: 220),
            FoodItem(name: '바나나 1개', calories: 90),
            FoodItem(name: '아메리카노', calories: 5),
          ],
        ),
        DietEntry(
          id: 'mock-lunch',
          mealType: MealType.lunch,
          timeLabel: '12:40',
          totalCalories: 530,
          sodiumMg: 1120,
          sugarG: 14,
          foods: <FoodItem>[
            FoodItem(name: '닭가슴살 샐러드', calories: 380),
            FoodItem(name: '현미밥 반공기', calories: 150),
          ],
        ),
        DietEntry(
          id: 'mock-dinner',
          mealType: MealType.dinner,
          timeLabel: '19:00',
          totalCalories: 575,
          sodiumMg: 600,
          sugarG: 13,
          foods: <FoodItem>[
            FoodItem(name: '연어 스테이크', calories: 420),
            FoodItem(name: '구운 야채', calories: 155),
          ],
        ),
      ],
      totalCalories: 1420,
      totalSodiumMg: 2100,
      totalSugarG: 45,
      macros: DietMacros(carbsPct: 50, proteinPct: 30, fatPct: 20),
      aiCoachMessage: '오늘 점심에 나트륨이 많았어요. 저녁은 담백한 구이/샐러드로 균형을 맞춰봐요!',
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
    int? sugarG,
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
