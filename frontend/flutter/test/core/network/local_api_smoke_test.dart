import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/core/network/interceptors/local_api_interceptor.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/storage/seed_data.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';

/// End-to-end smoke test for Stage 9: drift seeded → dio → LocalApi
/// interceptor → JSON → fromJson factory. If any of these layers
/// drift apart, this lights up first.
void main() {
  late AppDatabase db;
  late Dio dio;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfEmpty(db); // production seed path
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(LocalApiInterceptor(db, Logger(level: Level.off)));
  });

  tearDown(() async {
    await db.close();
    dio.close();
  });

  test('dio → LocalApi → DietDay.fromJson round-trips totals', () async {
    final res = await dio.get<Map<String, Object?>>('/diet/days/today');
    final day = DietDay.fromJson(res.data!);
    expect(day.entries.length, 4);
    expect(day.totalCalories, 1517);
    expect(day.totalSodiumMg, 4008);
    expect(day.totalSugarG, closeTo(24.8, 0.001));
    expect(day.macros.carbsG, closeTo(140.0, 0.001));
    expect(day.macros.proteinG, closeTo(79.0, 0.001));
    expect(day.macros.fatG, closeTo(72.0, 0.001));
    expect(
      <int>[day.macros.carbsPct, day.macros.proteinPct, day.macros.fatPct],
      <int>[37, 21, 42],
    );
    expect(
      day.entries
          .firstWhere((entry) => entry.mealType == MealType.dinner)
          .photoAsset,
      'assets/images/diet-tofu-salad.jpg',
    );
    final pastRes = await dio.get<Map<String, Object?>>(
      '/diet/days/${_daysAgoString(2)}',
    );
    final pastDay = DietDay.fromJson(pastRes.data!);
    expect(
      pastDay.entries
          .firstWhere((entry) => entry.mealType == MealType.dinner)
          .photoAsset,
      'assets/images/diet-salmon-brown-rice.jpeg',
    );
  });

  test('dio → LocalApi → ExerciseWeek.fromJson stays Mon..Sun', () async {
    final res = await dio.get<Map<String, Object?>>('/exercise/weeks/current');
    final week = ExerciseWeek.fromJson(res.data!);
    expect(week.dailyMinutes.length, 7);
    expect(week.dayLabels, <String>['월', '화', '수', '목', '금', '토', '일']);
    // v2 seed has multi-type rows per day so the stacked chart fills.
    // Sum: 월 40 + 화 60 + 수 50 + 목 65 + 금 55 + 토 80 + 일 0 = 350.
    expect(week.totalMinutes, 350);
    // 홈 '주간 추이' 차트가 데모 상수로 폴백하지 않도록 일별 칼로리도 내려준다.
    expect(week.dailyCalories.length, 7);
    expect(week.dailyCalories.reduce((a, b) => a + b), week.totalCalories);
    // 운동한 요일 수 == 분이 0보다 큰 요일 수.
    expect(
      week.workoutCount,
      week.dailyMinutes.where((double m) => m > 0).length,
    );
  });

  test('dio → LocalApi → DashboardSummary aggregates seeded data', () async {
    final res = await dio.get<Map<String, Object?>>('/dashboard/summary');
    final summary = DashboardSummary.fromJson(res.data!);
    final dietRes = await dio.get<Map<String, Object?>>('/diet/days/today');
    final todayDiet = DietDay.fromJson(dietRes.data!);
    // 혈당 row was removed from the home summary; indicator list now
    // ends at 당류 (calories / sodium / sugar).
    expect(summary.indicators.length, 3);
    final cal = summary.indicators.firstWhere((i) => i.label == '칼로리');
    final sodium = summary.indicators.firstWhere((i) => i.label == '나트륨');
    final sugar = summary.indicators.firstWhere((i) => i.label == '당류');
    expect(cal.current, todayDiet.totalCalories);
    expect(sodium.current, todayDiet.totalSodiumMg);
    expect(sugar.current, todayDiet.totalSugarG);
    expect(
      summary.indicators.any((i) => i.label == '혈당'),
      isFalse,
      reason: '혈당 row should no longer be in the home summary',
    );
    // 4 seeded meals (아침·점심·저녁·간식).
    expect(summary.dietEntries, todayDiet.entries.length);
    expect(summary.macros.carbsG, todayDiet.macros.carbsG);
    expect(summary.macros.proteinG, todayDiet.macros.proteinG);
    expect(summary.macros.fatG, todayDiet.macros.fatG);
    expect(summary.macros.carbsPct, todayDiet.macros.carbsPct);
    expect(summary.nutritionWeek, hasLength(7));
    final todayTrend = summary.nutritionWeek[DateTime.now().weekday - 1];
    expect(todayTrend.calories, todayDiet.totalCalories);
    expect(todayTrend.sodiumMg, todayDiet.totalSodiumMg);
    expect(todayTrend.sugarG, todayDiet.totalSugarG);
    // 시드가 큐레이션한 '통합 조언'이 동적 나트륨 경고 대신 노출된다. 문구가
    // 아니라 키로 내려와야 화면이 로케일에 맞게 고를 수 있다(#435).
    expect(summary.aiAdviceKey, kDailyCombinedAdviceKey);
    expect(summary.sodiumWarning, isNull);
    // Two baseline events always fall on today. One of the monthly demo
    // events can also land on today (5th/12th/22nd/26th), so keep this
    // assertion stable across the calendar while still checking the baseline.
    expect(
      summary.todaySchedule.map((item) => item.title),
      containsAll(<String>['병원 정기검진', '헬스장 운동']),
    );
    expect(summary.todaySchedule.length, inInclusiveRange(2, 3));
  });
}

String _daysAgoString(int days) {
  final date = DateTime.now().subtract(Duration(days: days));
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
