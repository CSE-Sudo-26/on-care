import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/diet/data/repositories/dio_diet_repository.dart';
import 'package:oncare/features/diet/data/sources/image_picker_meal_photo_picker.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';
import 'package:oncare/features/diet/domain/repositories/meal_photo_picker.dart';

/// 식단 저장소 — 빌드와 무관하게 **항상** 네트워크 구현이다.
///
/// 데모 응답은 `LocalApiInterceptor` 가 drift 에서 만들어 준다. AI 코치가 이미 쓰는
/// 구조이고, 식단만 저장소 단에서 갈라져 있던 것이 `REAL_API=diet` 를 죽은 스위치로
/// 만들었다 — 인메모리 구현은 Dio 를 타지 않으니 인터셉터의 통과 규칙에 닿을 일이
/// 없었다(#616).
///
/// 이제 분석 요청만 실 백엔드로 흘려보낼 수 있고, 나머지 조회·수정·삭제는 그대로
/// 로컬이 답하므로 데모 화면이 움직이지 않는다.
final dietRepositoryProvider = Provider<DietRepository>((ref) {
  return DioDietRepository(ref.watch(dioProvider));
}, name: 'dietRepository');

/// Camera / photo-library access for 식단 추가. Overridden in tests to play
/// back a capture, a cancel, or a denied permission without the plugin.
final mealPhotoPickerProvider = Provider<MealPhotoPicker>((ref) {
  return ImagePickerMealPhotoPicker();
}, name: 'mealPhotoPicker');

final dietTodayProvider = FutureProvider<DietDay>((ref) {
  return ref.watch(dietRepositoryProvider).fetchToday();
}, name: 'dietToday');

final _dietByDateFamily = FutureProvider.family<DietDay, DateTime>((ref, date) {
  return ref.watch(dietRepositoryProvider).fetchByDate(date);
}, name: 'dietByDate');

FutureProvider<DietDay> dietByDateProvider(DateTime date) {
  return _dietByDateFamily(DateTime(date.year, date.month, date.day));
}

/// 홈 "AI 추천 식단" — GET /diet/recommendations.
///
/// 홈 진입을 막지 않는 게 요구사항이라, 소비하는 쪽은 이 provider 가 값을 내기
/// 전이나 실패했을 때 [MealRecommendations.fallback] 을 그린다. 그래서 여기서
/// 로딩/에러 상태를 따로 표현하지 않는다(스켈레톤 없음 = 화면 깜빡임 없음).
final dietRecommendationsProvider = FutureProvider<MealRecommendations>((ref) {
  return ref.watch(dietRepositoryProvider).fetchRecommendations();
}, name: 'dietRecommendations');
