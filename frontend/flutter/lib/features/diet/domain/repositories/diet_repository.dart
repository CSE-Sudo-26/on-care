import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/meal_photo.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';

abstract class DietRepository {
  Future<DietDay> fetchToday();

  Future<DietDay> fetchByDate(DateTime date);

  /// GET /diet/recommendations — 홈 "AI 추천 식단".
  ///
  /// 서버가 최근 식단·건강 목표를 근거로 카탈로그에서 고른 결과다. 실패해도
  /// 홈 화면이 비지 않도록, 호출부는 결과가 오기 전/에러 시 기본 추천을 그린다.
  Future<MealRecommendations> fetchRecommendations();

  /// 기간에 맞는 식단 조언. (#1017)
  ///
  /// [period] 는 화면의 기간 토글과 같은 이름(`today`·`week`·`all`)이다. 구간
  /// 경계는 서버가 정한다 — 앱과 트레이너웹이 각자 계산하면 같은 회원의
  /// `이번 주` 가 화면마다 다른 날부터 시작한다.
  Future<String> fetchAdvice(String period);

  /// Upload a food photo for AI analysis (POST /diet/analyze). The server
  /// recognizes the foods, maps nutrition from the public DB, persists a
  /// diet entry, and returns the analysis.
  ///
  /// [photo] carries the bytes together with the file name and MIME type
  /// that describe them, so the multipart part the server validates always
  /// matches the actual image (see [MealPhoto]).
  ///
  /// [idempotencyKey], when supplied, lets the server dedupe a retried
  /// request (lost-response case) so the same photo isn't recorded twice.
  /// Generate it once per capture and reuse it across retries.
  Future<DietAnalysisResult> analyze({
    required MealPhoto photo,
    required String mealType,
    String? idempotencyKey,
  });

  /// DELETE /diet/entries/{id} — remove a diet entry.
  Future<void> deleteEntry(String id);

  /// PUT /diet/entries/{id} — edit an entry's date, meal type, time, foods,
  /// and nutrition values corrected from the analysis result.
  ///
  /// [date] 는 `YYYY-MM-DD` 다. 사진 분석은 저장한 시각의 날짜로 기록을 남기는데,
  /// 지난 식사의 사진을 나중에 올리는 일이 있어 실제로 먹은 날로 옮길 수 있어야
  /// 한다(#1241). 아직 오지 않은 날은 서버가 거절한다.
  Future<DietEntry> updateEntry({
    required String id,
    String? date,
    String? mealType,
    String? timeLabel,
    List<FoodItem>? foods,
    int? totalCalories,
    int? sodiumMg,
    double? sugarG,
  });
}
