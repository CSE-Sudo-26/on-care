import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/data/repositories/dio_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';

void main() {
  late Dio dio;
  late DioDietRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          handler.resolve(
            Response<Map<String, Object?>>(
              requestOptions: options,
              statusCode: 200,
              data: _staleResponse,
            ),
          );
        },
      ),
    );
    repository = DioDietRepository(dio);
  });

  tearDown(() {
    dio.close();
  });

  test(
    'edited foods determine override macros when response is stale',
    () async {
      const editedFoods = <FoodItem>[
        FoodItem(
          name: '현미밥',
          calories: 220,
          carbsG: 46,
          proteinG: 5,
          fatG: 1.8,
        ),
        FoodItem(name: '닭가슴살', calories: 165, proteinG: 31, fatG: 3.6),
      ];

      final updated = await repository.updateEntry(
        id: 'diet-edit',
        foods: editedFoods,
        totalCalories: 385,
        sodiumMg: 79,
        sugarG: 2.5,
      );

      expect(updated.foods, same(editedFoods));
      expect(updated.carbsG, 46);
      expect(updated.proteinG, 36);
      expect(updated.fatG, closeTo(5.4, 0.001));
      expect(updated.carbsG, isNot(_staleResponse['carbs_g']));
      expect(updated.proteinG, isNot(_staleResponse['protein_g']));
      expect(updated.fatG, isNot(_staleResponse['fat_g']));
      expect(updated.sodiumMg, 79);
      expect(updated.sugarG, 2.5);
    },
  );

  test(
    'update without foods keeps returned macros and local nutrition',
    () async {
      final updated = await repository.updateEntry(
        id: 'diet-edit',
        mealType: 'dinner',
        sodiumMg: 444,
        sugarG: 5.5,
      );

      expect(updated.foods.single.name, '기존 음식');
      expect(updated.carbsG, 90);
      expect(updated.proteinG, 8);
      expect(updated.fatG, 7);
      expect(updated.sodiumMg, 444);
      expect(updated.sugarG, 5.5);
    },
  );
}

const Map<String, Object?> _staleResponse = <String, Object?>{
  'id': 'diet-edit',
  'meal_type': 'lunch',
  'time_label': '12:00',
  'foods': <Object?>[
    <String, Object?>{
      'name': '기존 음식',
      'calories': 100,
      'sodium_mg': 100,
      'sugar_g': 1,
      'carbs_g': 90,
      'protein_g': 8,
      'fat_g': 7,
    },
  ],
  'total_calories': 100,
  'sodium_mg': 100,
  'sugar_g': 1,
  'carbs_g': 90,
  'protein_g': 8,
  'fat_g': 7,
};
