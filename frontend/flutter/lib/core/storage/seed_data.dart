import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:oncare/core/storage/app_database.dart';

/// Date-aware idempotent seeder. Runs at bootstrap.
///
/// **Flag format (v4+).** `AppKeyValues['seeded_v4']` stores the
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
  final today = _fmtDate(DateTime.now());
  final weekStart = _fmtDate(_mondayOfThisWeek(DateTime.now()));

  final seedDate = await db.readValue('seeded_v5');
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

  // Drop legacy flags (v2 boolean, v3 date) if still around, so a fresh
  // `readValue` next boot only sees the v4 key. Bumping v3→v4 forces every
  // existing install to re-seed once (식단 3끼·짬뽕·통합 조언 반영).
  await db.deleteValue('seeded_v2');
  await db.deleteValue('seeded_v3');
  await db.deleteValue('seeded_v4');
  // Also clear the curated KV advice so re-seed state is fully reset: this
  // version re-writes it below, but if a later seed drops or renames the key
  // an existing install would otherwise keep the stale text forever.
  await db.deleteValue('dashboard_ai_advice');

  await db.transaction(() async {
    // ---- Diet entries (3 meals for today) ----
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
          sugarG: const Value(6),
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
              // 오늘 3끼 합계가 탄120·단45·지45g(→ 45/17/38%)이 되도록 맞춘 값.
              'carbs_g': 107.0,
              'protein_g': 29.0,
              'fat_g': 22.5,
            },
          ]),
          totalCalories: 750,
          sodiumMg: const Value(3200),
          sugarG: const Value(9),
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
          sugarG: const Value(3),
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

  // 홈 '오늘의 AI 통합 조언' 문구(큐레이션). 대시보드 요약이 이 값이 있으면
  // 나트륨 급원 기반 동적 경고 대신 이 통합 조언을 노출한다.
  await db.putValue(
    'dashboard_ai_advice',
    '아침 식단과 저녁 PT 수업은 완벽했습니다! 다만 점심 짬뽕으로 높아진 나트륨과 혈당을 낮추기 위해, 물을 충분히 마시고 코치님이 강조하신 어깨 스트레칭으로 오늘 하루를 건강하게 마무리해 보세요.',
  );

  await db.putValue('seeded_v5', today);
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _mondayOfThisWeek(DateTime now) {
  final weekday = now.weekday; // 1 = Mon ... 7 = Sun
  return DateTime(now.year, now.month, now.day - (weekday - 1));
}
