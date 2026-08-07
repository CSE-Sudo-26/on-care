import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/diet/data/repositories/dio_diet_repository.dart';
import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';

final dietRepositoryProvider = Provider<DietRepository>((ref) {
  // In local/demo mode serve the fully-populated mock day (food photos,
  // per-food nutrition, per-meal AI feedback) so the diet tab renders
  // real-looking data with no backend. The real REST repo is used otherwise.
  if (ref.watch(appConfigProvider).useMockApi) {
    // One instance per provider lifetime so in-memory CRUD (analyze/edit/
    // delete) persists across `dietTodayProvider` invalidations for the session.
    return MockDietRepository();
  }
  return DioDietRepository(ref.watch(dioProvider));
}, name: 'dietRepository');

final dietTodayProvider = FutureProvider<DietDay>((ref) {
  return ref.watch(dietRepositoryProvider).fetchToday();
}, name: 'dietToday');

/// 홈 "AI 추천 식단" — GET /diet/recommendations.
///
/// 홈 진입을 막지 않는 게 요구사항이라, 소비하는 쪽은 이 provider 가 값을 내기
/// 전이나 실패했을 때 [MealRecommendations.fallback] 을 그린다. 그래서 여기서
/// 로딩/에러 상태를 따로 표현하지 않는다(스켈레톤 없음 = 화면 깜빡임 없음).
final dietRecommendationsProvider = FutureProvider<MealRecommendations>((ref) {
  return ref.watch(dietRepositoryProvider).fetchRecommendations();
}, name: 'dietRecommendations');
