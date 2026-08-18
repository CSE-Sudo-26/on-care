import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/core/network/interceptors/local_api_interceptor.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/utils/clock.dart';

String _todayDateString() {
  final now = nowKst();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  late AppDatabase db;
  late Dio dio;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(LocalApiInterceptor(db, Logger(level: Level.off)));

    final today = _todayDateString();
    await db.batch((b) {
      b.insertAll(db.scheduleEvents, <ScheduleEventsCompanion>[
        ScheduleEventsCompanion.insert(
          id: 'evt-1',
          date: today,
          time: '10:00',
          title: '병원 정기검진',
          category: 'hospital',
        ),
        ScheduleEventsCompanion.insert(
          id: 'evt-2',
          date: today,
          time: '18:00',
          title: '헬스장 운동',
          category: 'exercise',
        ),
        // Different date — must NOT appear in today's response.
        ScheduleEventsCompanion.insert(
          id: 'evt-3',
          date: '2000-01-01',
          time: '12:00',
          title: '아카이브',
          category: 'other',
        ),
      ]);
    });
  });

  tearDown(() async {
    await db.close();
    dio.close();
  });

  test('GET /schedule/events?date=<today> returns matching rows', () async {
    final res = await dio.get<List<Object?>>(
      '/schedule/events',
      queryParameters: <String, Object?>{'date': _todayDateString()},
    );
    expect(res.statusCode, 200);
    final list = res.data!.cast<Map<String, Object?>>();
    expect(list.length, 2);
    expect(list.map((e) => e['id']).toList(), <Object>['evt-1', 'evt-2']);
  });

  test('GET /schedule/events filters out other dates', () async {
    final res = await dio.get<List<Object?>>(
      '/schedule/events',
      queryParameters: <String, Object?>{'date': '2000-01-01'},
    );
    final list = res.data!.cast<Map<String, Object?>>();
    expect(list.length, 1);
    expect(list.first['title'], '아카이브');
  });
}
