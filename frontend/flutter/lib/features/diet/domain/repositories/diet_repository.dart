import 'dart:typed_data';

import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';

abstract class DietRepository {
  Future<DietDay> fetchToday();

  /// GET /diet/recommendations — 홈 "AI 추천 식단".
  ///
  /// 서버가 최근 식단·건강 목표를 근거로 카탈로그에서 고른 결과다. 실패해도
  /// 홈 화면이 비지 않도록, 호출부는 결과가 오기 전/에러 시 기본 추천을 그린다.
  Future<MealRecommendations> fetchRecommendations();

  /// Upload a food photo for AI analysis (POST /diet/analyze). The server
  /// recognizes the foods, maps nutrition from the public DB, persists a
  /// diet entry, and returns the analysis.
  ///
  /// [idempotencyKey], when supplied, lets the server dedupe a retried
  /// request (lost-response case) so the same photo isn't recorded twice.
  /// Generate it once per capture and reuse it across retries.
  Future<DietAnalysisResult> analyze({
    required Uint8List imageBytes,
    required String filename,
    required String mealType,
    String? idempotencyKey,
  });

  /// DELETE /diet/entries/{id} — remove a diet entry.
  Future<void> deleteEntry(String id);

  /// PUT /diet/entries/{id} — edit an entry's meal type, time, foods, and
  /// nutrition values corrected from the analysis result.
  Future<DietEntry> updateEntry({
    required String id,
    String? mealType,
    String? timeLabel,
    List<FoodItem>? foods,
    int? totalCalories,
    int? sodiumMg,
    double? sugarG,
  });
}
