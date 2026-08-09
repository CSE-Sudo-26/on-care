import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/core/storage/app_database.dart';

/// Date-aware idempotent seeder. Runs at bootstrap.
///
/// **Flag format (v4+).** `AppKeyValues['seeded_v13']` stores the
/// *date string* the seed last ran with (`YYYY-MM-DD`). Behaviour:
///
/// - `null` (first ever boot, or upgrading from v1/v2) — wipe any
///   stale `seed-%`-prefixed rows and insert a fresh seed for today.
/// - `flag == today` — no-op (seed already matches the current date).
/// - `flag != today` — slide the seed forward: wipe `seed-%`-prefixed
///   rows and re-insert with today's date / current week's `weekStart`.
///   This keeps the dashboard non-empty on any subsequent calendar
///   day without re-running on every boot.
///
/// **Why this matters.** `LocalApiInterceptor._dashboardSummary`
/// aggregates `dietEntries` / `exerciseSessions` / `scheduleEvents`
/// in real time with `WHERE date = today`. The legacy `seeded_v2`
/// boolean flag would lock seed rows to the *first boot date* and
/// produce an all-zero dashboard for every visitor on subsequent days.
///
/// **User data is preserved.** Only rows whose `id` starts with
/// `seed-` are wiped — anything the app or user has inserted directly
/// keeps its independent `id` and survives the slide.
///
/// v2 (vs v1) introduced multi-type exercise sessions per day so the
/// `WeeklyActivity` stacked-bar chart renders the 유산소 / 근력 /
/// 스트레칭 breakdown the prototype shows.
Future<void> seedIfEmpty(AppDatabase db) async {
  final now = DateTime.now();
  final today = _fmtDate(now);
  final yesterday = _fmtDate(now.subtract(const Duration(days: 1)));
  final twoDaysAgo = _fmtDate(now.subtract(const Duration(days: 2)));
  final weekStart = _fmtDate(_mondayOfThisWeek(now));

  final seedDate = await db.readValue('seeded_v13');
  if (seedDate == today) {
    // Already seeded for today — leave both seed rows and user rows
    // untouched.
    return;
  }

  // Either first boot, upgrading from v1/v2, or date has rolled over.
  // Wipe every `seed-%`-prefixed row across all date-bearing tables
  // so the next insert lands cleanly. Non-seed rows (anything the
  // user actually entered) are not matched by the LIKE and survive.
  await db.transaction(() async {
    await (db.delete(db.dietEntries)..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.exerciseSessions,
    )..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.scheduleEvents,
    )..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.notificationItems,
    )..where((t) => t.id.like('seed-%'))).go();
  });

  // Drop legacy flags so existing installs receive the latest curated seed.
  await db.deleteValue('seeded_v2');
  await db.deleteValue('seeded_v3');
  await db.deleteValue('seeded_v4');
  await db.deleteValue('seeded_v5');
  await db.deleteValue('seeded_v6');
  await db.deleteValue('seeded_v7');
  await db.deleteValue('seeded_v8');
  await db.deleteValue('seeded_v9');
  await db.deleteValue('seeded_v10');
  await db.deleteValue('seeded_v11');
  await db.deleteValue('seeded_v12');
  // Also clear the curated KV advice so re-seed state is fully reset: this
  // version re-writes it below, but if a later seed drops or renames the key
  // an existing install would otherwise keep the stale text forever.
  await db.deleteValue('dashboard_ai_advice');

  await db.transaction(() async {
    // ---- Diet entries (today plus two populated historical days) ----
    await db.batch((Batch b) {
      b.insertAll(db.dietEntries, <DietEntriesCompanion>[
        DietEntriesCompanion.insert(
          id: 'seed-diet-breakfast',
          date: today,
          mealType: 'breakfast',
          timeLabel: '08:20',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '스크램블 에그',
              'calories': 185,
              'sodium_mg': 220,
              'sugar_g': 0.8,
              'carbs_g': 2.0,
              'protein_g': 13.0,
              'fat_g': 14.0,
            },
            <String, Object?>{
              'name': '딸기',
              'calories': 32,
              'sodium_mg': 1,
              'sugar_g': 5.5,
              'carbs_g': 8.0,
              'protein_g': 0.5,
              'fat_g': 0.5,
            },
          ]),
          totalCalories: 217,
          sodiumMg: const Value(221),
          sugarG: const Value(6.3),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-lunch',
          date: today,
          mealType: 'lunch',
          timeLabel: '12:40',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '짬뽕',
              'calories': 750,
              'sodium_mg': 3200,
              'sugar_g': 8.5,
              // 식단 탭과 홈 대시보드가 같은 행을 집계한다.
              'carbs_g': 107.0,
              'protein_g': 29.0,
              'fat_g': 22.5,
            },
          ]),
          totalCalories: 750,
          sodiumMg: const Value(3200),
          sugarG: const Value(8.5),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-snack',
          date: today,
          mealType: 'snack',
          timeLabel: '15:30',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '아이스 아메리카노',
              'calories': 10,
              'sodium_mg': 5,
              'sugar_g': 0,
              'carbs_g': 2.0,
              'protein_g': 0.5,
              'fat_g': 0.0,
            },
            <String, Object?>{
              'name': '견과류 한 봉',
              'calories': 90,
              'sodium_mg': 2,
              'sugar_g': 3,
              'carbs_g': 1.0,
              'protein_g': 2.0,
              'fat_g': 8.0,
            },
          ]),
          totalCalories: 100,
          sodiumMg: const Value(7),
          sugarG: const Value(3.0),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-yesterday-breakfast',
          date: yesterday,
          mealType: 'breakfast',
          timeLabel: '08:10',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '오트밀',
              'calories': 250,
              'sodium_mg': 100,
              'sugar_g': 6,
              'carbs_g': 42.0,
              'protein_g': 10.0,
              'fat_g': 6.0,
            },
            <String, Object?>{
              'name': '바나나',
              'calories': 105,
              'sodium_mg': 1,
              'sugar_g': 14,
              'carbs_g': 27.0,
              'protein_g': 1.3,
              'fat_g': 0.4,
            },
          ]),
          totalCalories: 355,
          sodiumMg: const Value(101),
          sugarG: const Value(20.0),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-yesterday-lunch',
          date: yesterday,
          mealType: 'lunch',
          timeLabel: '12:30',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '닭가슴살 샐러드',
              'calories': 315,
              'sodium_mg': 395,
              'sugar_g': 10,
              'carbs_g': 19.0,
              'protein_g': 34.0,
              'fat_g': 11.1,
            },
          ]),
          totalCalories: 315,
          sodiumMg: const Value(395),
          sugarG: const Value(10.0),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-yesterday-dinner',
          date: yesterday,
          mealType: 'dinner',
          timeLabel: '18:45',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '된장찌개',
              'calories': 300,
              'sodium_mg': 1300,
              'sugar_g': 5,
              'carbs_g': 18.0,
              'protein_g': 24.0,
              'fat_g': 15.0,
            },
            <String, Object?>{
              'name': '밥',
              'calories': 310,
              'sodium_mg': 5,
              'sugar_g': 0.7,
              'carbs_g': 67.0,
              'protein_g': 6.0,
              'fat_g': 2.5,
            },
          ]),
          totalCalories: 610,
          sodiumMg: const Value(1305),
          sugarG: const Value(5.7),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-two-days-ago-breakfast',
          date: twoDaysAgo,
          mealType: 'breakfast',
          timeLabel: '08:35',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '그릭 요거트',
              'calories': 170,
              'sodium_mg': 75,
              'sugar_g': 7,
              'carbs_g': 8.0,
              'protein_g': 18.0,
              'fat_g': 8.0,
            },
            <String, Object?>{
              'name': '견과류',
              'calories': 150,
              'sodium_mg': 5,
              'sugar_g': 2,
              'carbs_g': 6.0,
              'protein_g': 5.0,
              'fat_g': 13.0,
            },
          ]),
          totalCalories: 320,
          sodiumMg: const Value(80),
          sugarG: const Value(9.0),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-two-days-ago-lunch',
          date: twoDaysAgo,
          mealType: 'lunch',
          timeLabel: '12:20',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '야채비빔밥',
              'calories': 610,
              'sodium_mg': 900,
              'sugar_g': 12,
              'carbs_g': 92.0,
              'protein_g': 20.0,
              'fat_g': 16.0,
            },
          ]),
          totalCalories: 610,
          sodiumMg: const Value(900),
          sugarG: const Value(12.0),
        ),
        DietEntriesCompanion.insert(
          id: 'seed-diet-two-days-ago-dinner',
          date: twoDaysAgo,
          mealType: 'dinner',
          timeLabel: '18:50',
          foodsJson: jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'name': '연어구이',
              'calories': 395,
              'sodium_mg': 505,
              'sugar_g': 9,
              'carbs_g': 19.0,
              'protein_g': 35.0,
              'fat_g': 19.0,
            },
            <String, Object?>{
              'name': '현미밥',
              'calories': 280,
              'sodium_mg': 5,
              'sugar_g': 0,
              'carbs_g': 58.0,
              'protein_g': 6.0,
              'fat_g': 2.0,
            },
          ]),
          totalCalories: 675,
          sodiumMg: const Value(510),
          sugarG: const Value(9.0),
        ),
      ]);
    });

    // ---- Exercise sessions ----
    // Per-day breakdown matches the prototype's WeeklyActivity stack:
    // 월 40 (30+10), 화 60 (45+10+5), 수 50 (40+10),
    // 목 65 (50+10+5), 금 55 (45+5+5), 토 80 (30+30+20), 일 0.
    await db.batch((Batch b) {
      b.insertAll(db.exerciseSessions, <ExerciseSessionsCompanion>[
        // ---- Mon ----
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-mon-c',
          weekStart: weekStart,
          dayLabel: '월',
          type: 'cardio',
          minutes: 30,
          calories: 225,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-mon-s',
          weekStart: weekStart,
          dayLabel: '월',
          type: 'stretching',
          minutes: 10,
          calories: 30,
        ),
        // ---- Tue ----
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-tue-c',
          weekStart: weekStart,
          dayLabel: '화',
          type: 'cardio',
          minutes: 45,
          calories: 337,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-tue-w',
          weekStart: weekStart,
          dayLabel: '화',
          type: 'strength',
          minutes: 10,
          calories: 50,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-tue-s',
          weekStart: weekStart,
          dayLabel: '화',
          type: 'stretching',
          minutes: 5,
          calories: 15,
        ),
        // ---- Wed ----
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-wed-c',
          weekStart: weekStart,
          dayLabel: '수',
          type: 'cardio',
          minutes: 40,
          calories: 300,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-wed-s',
          weekStart: weekStart,
          dayLabel: '수',
          type: 'stretching',
          minutes: 10,
          calories: 30,
        ),
        // ---- Thu ----
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-thu-c',
          weekStart: weekStart,
          dayLabel: '목',
          type: 'cardio',
          minutes: 50,
          calories: 375,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-thu-w',
          weekStart: weekStart,
          dayLabel: '목',
          type: 'strength',
          minutes: 10,
          calories: 50,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-thu-s',
          weekStart: weekStart,
          dayLabel: '목',
          type: 'stretching',
          minutes: 5,
          calories: 15,
        ),
        // ---- Fri ----
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-fri-c',
          weekStart: weekStart,
          dayLabel: '금',
          type: 'cardio',
          minutes: 45,
          calories: 337,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-fri-w',
          weekStart: weekStart,
          dayLabel: '금',
          type: 'strength',
          minutes: 5,
          calories: 25,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-fri-s',
          weekStart: weekStart,
          dayLabel: '금',
          type: 'stretching',
          minutes: 5,
          calories: 15,
        ),
        // ---- Sat ----
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-sat-c',
          weekStart: weekStart,
          dayLabel: '토',
          type: 'cardio',
          minutes: 30,
          calories: 225,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-sat-w',
          weekStart: weekStart,
          dayLabel: '토',
          type: 'strength',
          minutes: 30,
          calories: 150,
        ),
        ExerciseSessionsCompanion.insert(
          id: 'seed-ex-sat-s',
          weekStart: weekStart,
          dayLabel: '토',
          type: 'stretching',
          minutes: 20,
          calories: 60,
        ),
      ]);
    });

    // ---- Today's schedule (2 events) ----
    await db.batch((Batch b) {
      b.insertAll(db.scheduleEvents, <ScheduleEventsCompanion>[
        ScheduleEventsCompanion.insert(
          id: 'seed-evt-hospital',
          date: today,
          time: '10:00',
          title: '병원 정기검진',
          category: 'hospital',
          emoji: const Value('🏥'),
          colorHex: const Value('#FEE2E2'),
        ),
        ScheduleEventsCompanion.insert(
          id: 'seed-evt-gym',
          date: today,
          time: '18:00',
          title: '헬스장 운동',
          category: 'exercise',
          emoji: const Value('💪'),
          colorHex: const Value('#DCFCE7'),
        ),
        // 월 전반에 흩뿌린 데모 일정(카테고리별) — 캘린더 색상 구분이
        // 보이도록. colorHex 는 생략(프론트가 category 로 색칠).
        ScheduleEventsCompanion.insert(
          id: 'seed-evt-nutrition',
          date: '${today.substring(0, 7)}-05',
          time: '14:00',
          title: '영양 상담',
          category: 'meal',
          emoji: const Value('🍽️'),
        ),
        ScheduleEventsCompanion.insert(
          id: 'seed-evt-med',
          date: '${today.substring(0, 7)}-12',
          time: '09:00',
          title: '혈압약 처방',
          category: 'medication',
          emoji: const Value('💊'),
        ),
        ScheduleEventsCompanion.insert(
          id: 'seed-evt-family',
          date: '${today.substring(0, 7)}-22',
          time: '12:00',
          title: '가족 모임',
          category: 'other',
          emoji: const Value('📌'),
        ),
        ScheduleEventsCompanion.insert(
          id: 'seed-evt-pt',
          date: '${today.substring(0, 7)}-26',
          time: '19:00',
          title: 'PT 세션',
          category: 'exercise',
          emoji: const Value('💪'),
        ),
      ]);
    });

    // ---- Notifications ----
    final now = DateTime.now();
    await db.batch((Batch b) {
      b.insertAll(db.notificationItems, <NotificationItemsCompanion>[
        NotificationItemsCompanion.insert(
          id: 'seed-noti-1',
          createdAt: now.subtract(const Duration(minutes: 10)),
          title: '식단 입력 알림',
          body: '오늘 점심 입력이 비어있어요.',
          category: 'reminder',
        ),
        NotificationItemsCompanion.insert(
          id: 'seed-noti-2',
          createdAt: now.subtract(const Duration(hours: 1)),
          title: '운동 목표 달성',
          body: '주간 운동 240분 달성!',
          category: 'achievement',
        ),
        NotificationItemsCompanion.insert(
          id: 'seed-noti-4',
          createdAt: now.subtract(const Duration(days: 1)),
          title: '서비스 점검 안내',
          body: '내일 02:00~03:00 점검 예정입니다.',
          category: 'system',
          read: const Value(true),
        ),
      ]);
    });
  });

  // 홈 '오늘의 AI 통합 조언'(큐레이션). 문구가 아니라 **키**를 저장한다 —
  // 문장은 ARB 가 ko·en 양쪽으로 갖고 있고 화면이 로케일에 맞게 고른다(#435).
  // 대시보드 요약은 이 값이 있으면 나트륨 급원 기반 동적 경고 대신 이 조언을
  // 노출한다.
  await db.putValue('dashboard_ai_advice', kDailyCombinedAdviceKey);

  await db.putValue('seeded_v13', today);
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _mondayOfThisWeek(DateTime now) {
  final weekday = now.weekday; // 1 = Mon ... 7 = Sun
  return DateTime(now.year, now.month, now.day - (weekday - 1));
}
