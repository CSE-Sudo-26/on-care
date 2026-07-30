import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/domain/entities/diet_day.dart';

void main() {
  test('DietDay constructs with entries, totals and coach message', () {
    const day = DietDay(
      entries: <DietEntry>[
        DietEntry(
          mealType: MealType.breakfast,
          timeLabel: '08:00',
          totalCalories: 300,
          foods: <FoodItem>[FoodItem(name: 'oat', calories: 300)],
          sodiumMg: 100,
          sugarG: 5,
        ),
      ],
      totalCalories: 300,
      totalSodiumMg: 100,
      totalSugarG: 5,
      macros: DietMacros(carbsPct: 60, proteinPct: 20, fatPct: 20),
      aiCoachMessage: 'hello',
    );
    expect(day.entries.first.mealType, MealType.breakfast);
    expect(day.totalCalories, 300);
    expect(day.totalSodiumMg, 100);
    expect(day.aiCoachMessage, 'hello');
  });

  test('DietDay parses meal and daily macro grams from API JSON', () {
    final day = DietDay.fromJson(<String, Object?>{
      'entries': <Object?>[
        <String, Object?>{
          'id': 'diet-lunch',
          'meal_type': 'lunch',
          'time_label': '12:40',
          'foods': <Object?>[
            <String, Object?>{
              'name': '김치찌개',
              'calories': 285,
              'sodium_mg': 900,
              'sugar_g': 4,
              'carbs_g': 16,
              'protein_g': 20,
              'fat_g': 15.5,
            },
          ],
          'total_calories': 285,
          'sodium_mg': 900,
          'sugar_g': 4,
          'carbs_g': 16,
          'protein_g': 20,
          'fat_g': 15.5,
        },
      ],
      'total_calories': 285,
      'total_sodium_mg': 900,
      'total_sugar_g': 4,
      'macros': <String, Object?>{
        'carbs_g': 16,
        'protein_g': 20,
        'fat_g': 15.5,
        'carbs_pct': 23,
        'protein_pct': 29,
        'fat_pct': 48,
      },
      'ai_coach_message': 'message',
    });

    expect(day.entries.single.carbsG, 16);
    expect(day.entries.single.proteinG, 20);
    expect(day.entries.single.fatG, 15.5);
    expect(day.entries.single.foods.single.sodiumMg, 900);
    expect(day.entries.single.foods.single.carbsG, 16);
    expect(day.macros.carbsG, 16);
    expect(day.macros.proteinG, 20);
    expect(day.macros.fatG, 15.5);
    expect(day.macros.carbsPct, 23);
  });

  test('missing macro fields in legacy JSON default to zero', () {
    final day = DietDay.fromJson(<String, Object?>{
      'entries': <Object?>[
        <String, Object?>{
          'meal_type': 'breakfast',
          'time_label': '08:00',
          'foods': <Object?>[
            <String, Object?>{'name': '바나나', 'calories': 105},
          ],
          'total_calories': 105,
        },
      ],
      'total_calories': 105,
      'total_sodium_mg': 0,
      'total_sugar_g': 0,
      'ai_coach_message': '',
    });

    expect(day.entries.single.carbsG, 0);
    expect(day.entries.single.foods.single.proteinG, 0);
    expect(day.macros.carbsG, 0);
    expect(day.macros.carbsPct, 0);
  });
}
