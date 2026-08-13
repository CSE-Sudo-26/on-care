import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/core/network/interceptors/local_api_interceptor.dart';
import 'package:oncare/core/storage/app_database.dart';

String _currentMonday() {
  final now = DateTime.now();
  final m = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return '${m.year.toString().padLeft(4, '0')}-'
      '${m.month.toString().padLeft(2, '0')}-'
      '${m.day.toString().padLeft(2, '0')}';
}

void main() {
  late AppDatabase db;
  late Dio dio;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(LocalApiInterceptor(db, Logger(level: Level.off)));

    // Seed a few sessions for the current week — same shape the
    // production `seedIfEmpty` would have written.
    final ws = _currentMonday();
    await db.batch((b) {
      b.insertAll(db.exerciseSessions, <ExerciseSessionsCompanion>[
        ExerciseSessionsCompanion.insert(
          id: 'ex-mon',
          weekStart: ws,
          dayLabel: '월',
          type: 'cardio',
          minutes: 30,
          calories: 250,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'ex-wed',
          weekStart: ws,
          dayLabel: '수',
          type: 'strength',
          minutes: 45,
          calories: 320,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'ex-fri',
          weekStart: ws,
          dayLabel: '금',
          type: 'cardio',
          minutes: 60,
          calories: 480,
        ),
      ]);
    });
  });

  tearDown(() async {
    await db.close();
    dio.close();
  });

  test(
    'GET /exercise/weeks/current aggregates daily minutes Mon..Sun',
    () async {
      final res = await dio.get<Map<String, Object?>>(
        '/exercise/weeks/current',
      );
      expect(res.statusCode, 200);
      final body = res.data!;

      final daily = (body['daily_minutes']! as List<Object?>)
          .cast<num>()
          .toList();
      // Mon=30, Tue=0, Wed=45, Thu=0, Fri=60, Sat=0, Sun=0.
      expect(daily, <num>[30, 0, 45, 0, 60, 0, 0]);

      expect(body['total_minutes'], 135);
      expect(body['total_calories'], 1050);
      // "N일 연속" = 가장 긴 연속 구간. 월·수·금은 서로 떨어져 있으므로 활성
      // 일수는 3이지만 연속은 1이다.
      expect(body['streak_days'], 1);
      // Day labels are always Mon..Sun in Korean.
      expect(body['day_labels'], <String>['월', '화', '수', '목', '금', '토', '일']);
    },
  );

  test('weeks/current ignores rows from other weeks', () async {
    // Inject a row tagged to a different weekStart — it shouldn't show up.
    await db
        .into(db.exerciseSessions)
        .insert(
          ExerciseSessionsCompanion.insert(
            id: 'ex-old',
            weekStart: '2000-01-03', // arbitrary Monday in the past
            dayLabel: '월',
            type: 'cardio',
            minutes: 999,
            calories: 9999,
          ),
        );
    final res = await dio.get<Map<String, Object?>>('/exercise/weeks/current');
    final daily = (res.data!['daily_minutes']! as List<Object?>)
        .cast<num>()
        .toList();
    expect(daily.first, 30); // monday still 30 — old row was filtered out
  });

  test('weeks/current returns zeros + empty list when no rows', () async {
    // Fresh DB with no inserts.
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final freshDio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    addTearDown(() async {
      freshDio.close();
    });
    freshDio.interceptors.add(
      LocalApiInterceptor(db, Logger(level: Level.off)),
    );
    final res = await freshDio.get<Map<String, Object?>>(
      '/exercise/weeks/current',
    );
    final body = res.data!;
    expect(body['total_minutes'], 0);
    expect(body['total_calories'], 0);
    expect(body['streak_days'], 0);
    expect((body['sessions']! as List<Object?>), isEmpty);
  });

  test('POST /exercise/sessions persists and shows up in weeks/current', () async {
    final add = await dio.post<Map<String, Object?>>(
      '/exercise/sessions',
      data: <String, Object?>{
        'type': 'cardio',
        'minutes': 40,
        'calories': 300,
        'day_label': '화',
      },
    );
    expect(add.statusCode, 200);
    expect(add.data!['type'], 'cardio');
    expect(add.data!['minutes'], 40);
    expect(add.data!['day_label'], '화');
    expect(add.data!['date_label'], isNotNull);

    // 재조회 시 화요일(0→40) 반영, 합계 증가(135→175).
    final res = await dio.get<Map<String, Object?>>('/exercise/weeks/current');
    final daily = (res.data!['daily_minutes']! as List<Object?>)
        .cast<num>()
        .toList();
    expect(daily, <num>[30, 40, 45, 0, 60, 0, 0]);
    expect(res.data!['total_minutes'], 175);
  });

  test('POST/PUT /exercise/sessions round-trips intensity', () async {
    final add = await dio.post<Map<String, Object?>>(
      '/exercise/sessions',
      data: <String, Object?>{
        'type': 'strength',
        'minutes': 40,
        'calories': 300,
        'intensity': 'high',
        'day_label': '화',
      },
    );
    expect(add.data!['intensity'], 'high');
    final String id = add.data!['id']! as String;

    // GET week echoes the saved intensity for that session.
    final week = await dio.get<Map<String, Object?>>('/exercise/weeks/current');
    final sessions = (week.data!['sessions']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final added = sessions.firstWhere((s) => s['id'] == id);
    expect(added['intensity'], 'high');

    // Editing to a lower intensity persists.
    final put = await dio.put<Map<String, Object?>>(
      '/exercise/sessions/$id',
      data: <String, Object?>{
        'type': 'strength',
        'minutes': 40,
        'calories': 250,
        'intensity': 'light',
        'day_label': '화',
      },
    );
    expect(put.data!['intensity'], 'light');
  });

  test('POST /exercise/sessions defaults intensity to moderate', () async {
    final add = await dio.post<Map<String, Object?>>(
      '/exercise/sessions',
      data: <String, Object?>{'type': 'cardio', 'minutes': 20, 'day_label': '목'},
    );
    expect(add.data!['intensity'], 'moderate');
  });

  test('POST /exercise/sessions rejects non-positive minutes', () async {
    final res = await dio.post<Map<String, Object?>>(
      '/exercise/sessions',
      data: <String, Object?>{'type': 'cardio', 'minutes': 0},
      options: Options(validateStatus: (int? s) => true),
    );
    expect(res.statusCode, 400);
  });

  test('week_start 로 지난 주를 조회한다 (#671)', () async {
    // 지난 주 월요일에 세션 하나. 이번 주 시드와 섞이면 안 된다.
    final DateTime lastMonday = DateTime.parse(
      _currentMonday(),
    ).subtract(const Duration(days: 7));
    final String lastWeek =
        '${lastMonday.year.toString().padLeft(4, '0')}-'
        '${lastMonday.month.toString().padLeft(2, '0')}-'
        '${lastMonday.day.toString().padLeft(2, '0')}';
    await db
        .into(db.exerciseSessions)
        .insert(
          ExerciseSessionsCompanion.insert(
            id: 'ex-last-mon',
            weekStart: lastWeek,
            dayLabel: '월',
            type: 'cardio',
            minutes: 20,
            calories: 140,
          ),
        );

    final res = await dio.get<Map<String, Object?>>(
      '/exercise/weeks/current',
      queryParameters: <String, Object?>{'week_start': lastWeek},
    );
    expect(res.data!['total_minutes'], 20);
    expect((res.data!['sessions']! as List<Object?>).length, 1);

    // 파라미터가 없으면 예전 그대로 이번 주다.
    final current = await dio.get<Map<String, Object?>>(
      '/exercise/weeks/current',
    );
    expect(current.data!['total_minutes'], isNot(20));
  });

  test('지난 주 세션의 date_label 은 오늘/어제로 잘못 붙지 않는다 (#671)', () async {
    final DateTime lastMonday = DateTime.parse(
      _currentMonday(),
    ).subtract(const Duration(days: 7));
    final String lastWeek =
        '${lastMonday.year.toString().padLeft(4, '0')}-'
        '${lastMonday.month.toString().padLeft(2, '0')}-'
        '${lastMonday.day.toString().padLeft(2, '0')}';
    await db
        .into(db.exerciseSessions)
        .insert(
          ExerciseSessionsCompanion.insert(
            id: 'ex-last-tue',
            weekStart: lastWeek,
            dayLabel: '화',
            type: 'cardio',
            minutes: 30,
            calories: 200,
          ),
        );

    final res = await dio.get<Map<String, Object?>>(
      '/exercise/weeks/current',
      queryParameters: <String, Object?>{'week_start': lastWeek},
    );
    final sessions = (res.data!['sessions']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final DateTime lastTuesday = lastMonday.add(const Duration(days: 1));
    expect(
      sessions.single['date_label'],
      '${lastTuesday.month}월 ${lastTuesday.day}일',
    );
  });

  test('week_start 형식이 깨지면 400 이다', () async {
    final res = await dio.get<Map<String, Object?>>(
      '/exercise/weeks/current',
      queryParameters: <String, Object?>{'week_start': 'not-a-date'},
      options: Options(validateStatus: (int? s) => true),
    );
    expect(res.statusCode, 400);
  });
}
