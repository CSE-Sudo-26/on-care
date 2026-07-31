import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

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
    expect(day.entries.length, 3);
    expect(day.totalCalories, 1067);
    expect(day.totalSodiumMg, 3428);
    expect(day.macros.carbsG, closeTo(113.0, 0.001));
    expect(day.macros.proteinG, closeTo(46.0, 0.001));
    expect(day.macros.fatG, closeTo(46.5, 0.001));
    expect(
      <int>[day.macros.carbsPct, day.macros.proteinPct, day.macros.fatPct],
      <int>[43, 17, 40],
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
  });

  test('dio → LocalApi → DashboardSummary aggregates seeded data', () async {
    final res = await dio.get<Map<String, Object?>>('/dashboard/summary');
    final summary = DashboardSummary.fromJson(res.data!);
    // 혈당 row was removed from the home summary; indicator list now
    // ends at 당류 (calories / sodium / sugar).
    expect(summary.indicators.length, 3);
    final cal = summary.indicators.firstWhere((i) => i.label == '칼로리');
    expect(cal.current, 1067);
    expect(
      summary.indicators.any((i) => i.label == '혈당'),
      isFalse,
      reason: '혈당 row should no longer be in the home summary',
    );
    // 3 seeded meals (아침·점심·간식).
    expect(summary.dietEntries, 3);
    expect(summary.macros.carbsG, 113.0);
    expect(summary.macros.proteinG, 46.0);
    expect(summary.macros.fatG, 46.5);
    expect(summary.macros.carbsPct, 43);
    // 시드가 큐레이션한 '통합 조언'(짬뽕 시나리오)이 동적 경고 대신 노출된다.
    expect(summary.sodiumWarning, contains('짬뽕'));
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
