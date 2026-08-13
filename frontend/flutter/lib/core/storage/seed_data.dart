import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/core/storage/app_database.dart';

/// 하루 단위 코치 문구(날짜 → 문장)를 담는 키-값 키.
///
/// 끼니가 아니라 **하루**에 붙는 문장이라 `dietEntries` 행에 둘 자리가 없고, 시연용
/// 날짜 셋뿐이라 테이블을 새로 만들 이유도 없다. 시드가 쓰고 로컬 인터셉터가 읽는다.
///
/// 날짜별로 키를 나누지 않고 한 키에 묶는 이유: 시드는 날이 바뀌면 앞으로 미끄러지는데,
/// 키를 날짜마다 만들면 지난 날짜 키가 계속 쌓인다. 한 키를 통째로 덮어쓰면 그 문제가 없다.
const String kDietDayMessagesKey = 'diet_day_messages';

/// 큐레이션 사흘(오늘·어제·그제) **앞으로** 더 채우는 과거 일수.
///
/// 데모에서 날짜를 옮기면 대부분 "기록이 없어요"만 나오던 문제(#671)를 없앤다.
/// 주간 스트립은 오늘 앞뒤 3일을 보여주고 주 단위로 뒤로 넘어갈 수 있으므로,
/// 한 달치를 채워 두면 지난주로 넘겨도 기록이 이어진다.
const int kDemoDietHistoryDays = 30;

/// 현재 주 **앞으로** 시드하는 지난 주 수. 운동은 주 단위(`weekStart`)로
/// 조회하므로 날짜가 아니라 주로 센다.
const int kDemoExerciseHistoryWeeks = 4;

/// Date-aware idempotent seeder. Runs at bootstrap.
///
/// **Flag format (v4+).** `AppKeyValues['seeded_v15']` stores the
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

  final seedDate = await db.readValue('seeded_v15');
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
  // v14: 끼니별 AI 코멘트·사진이 행으로 내려오고 하루 코치 문구가 추가됐다.
  // 플래그를 올리지 않으면 오늘 이미 시드된 설치가 빈 코멘트를 그대로 들고 있게 된다.
  await db.deleteValue('seeded_v13');
  // v15: 과거 한 달치 식단·지난 4주 운동이 추가됐다(#671). 올리지 않으면 오늘
  // 이미 시드된 설치가 사흘치 그대로 남아 날짜를 옮겨도 여전히 비어 보인다.
  await db.deleteValue('seeded_v14');
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
          aiComment: const Value('단백질과 식이섬유의 깔끔한 조합으로, 소금 간과 기름만 조절하면 혈당과 혈압 모두 잡는 우수한 식단입니다.'),
          photoAsset: const Value('assets/images/breakfast-scrambled-egg-strawberry.jpg'),
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
          aiComment: const Value('정제 면과 높은 나트륨으로 혈압·혈당 부담이 매우 크니, 국물은 남기고 야채 위주로 드시는 것이 좋습니다.'),
          photoAsset: const Value('assets/images/lunch-jjamppong.jpg'),
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
          aiComment: const Value('당류와 칼로리가 낮고 견과류의 건강한 지방이 채워져 완벽한 간식입니다.'),
          photoAsset: const Value('assets/images/snack-coffee-nuts.jpg'),
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
          aiComment: const Value('오트밀로 식이섬유를 챙겼어요. 바나나가 들어가 당류는 다소 높은 편이에요.'),
          photoAsset: const Value('assets/images/diet-oatmeal-banana.jpeg'),
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
          aiComment: const Value('닭가슴살과 채소로 단백질과 식이섬유를 고르게 섭취했어요.'),
          photoAsset: const Value('assets/images/diet-chicken-salad.jpg'),
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
          aiComment: const Value('밥과 찌개를 함께 섭취해 포만감은 좋지만 국물은 조금 남기면 좋아요.'),
          photoAsset: const Value('assets/images/diet-doenjang-rice.jpeg'),
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
          aiComment: const Value('그릭 요거트의 단백질과 견과류의 불포화지방을 고르게 섭취했어요.'),
          photoAsset: const Value('assets/images/diet-greek-yogurt-nuts.jpeg'),
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
          aiComment: const Value('야채가 풍부한 비빔밥이에요. 고추장을 줄이면 나트륨을 더 조절할 수 있어요.'),
          photoAsset: const Value('assets/images/diet-vegetable-bibimbap.jpg'),
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
          aiComment: const Value('연어의 지방과 현미밥의 복합 탄수화물 조합이 좋아요.'),
          photoAsset: const Value('assets/images/diet-salmon-brown-rice.jpeg'),
        ),
        // 큐레이션 사흘 앞으로 한 달치를 더 채운다 — 날짜를 옮겨도 기록이
        // 이어지도록(#671).
        ..._historyDietEntries(now),
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
        // 지난 주들 — 운동 탭에서 주를 뒤로 넘겨도 기록이 이어지도록(#671).
        ..._historyExerciseSessions(now),
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

  // 식단 탭의 하루 코치 문구. 시연에 쓰는 세 날짜만 문장을 정해 두고, 그 밖의
  // 날짜는 인터셉터가 수치를 보고 만든 문구로 대신한다([kDietDayMessagesKey]).
  await db.putValue(
    kDietDayMessagesKey,
    jsonEncode(<String, String>{
      today: '점심 짬뽕으로 오늘 나트륨 섭취가 많았어요. 저녁은 양념을 줄인 채소와 단백질 위주로 구성해 보세요.',
      yesterday: '나트륨을 잘 조절했고 단백질도 고르게 섭취한 하루였어요.',
      twoDaysAgo: '연어와 현미밥으로 탄단지 균형을 잘 맞췄어요.',
    }),
  );

  await db.putValue('seeded_v15', today);
}

// ─────────────────────────────────────────────── 과거 기록 (데모 히스토리) ──

/// 한 가지 음식. 화면이 읽는 키(`sodium_mg` 등)와 같은 이름을 쓴다.
class _SeedFood {
  const _SeedFood(
    this.name, {
    required this.calories,
    required this.sodiumMg,
    required this.sugarG,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
  });

  final String name;
  final int calories;
  final int sodiumMg;
  final double sugarG;
  final double carbsG;
  final double proteinG;
  final double fatG;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'calories': calories,
    'sodium_mg': sodiumMg,
    'sugar_g': sugarG,
    'carbs_g': carbsG,
    'protein_g': proteinG,
    'fat_g': fatG,
  };
}

/// 한 끼니 템플릿. 날짜만 갈아 끼우면 그날의 기록이 된다.
class _SeedMeal {
  const _SeedMeal({
    required this.slug,
    required this.mealType,
    required this.timeLabel,
    required this.foods,
    required this.aiComment,
    this.photoAsset = '',
  });

  final String slug;
  final String mealType;
  final String timeLabel;
  final List<_SeedFood> foods;
  final String aiComment;
  final String photoAsset;

  int get totalCalories =>
      foods.fold<int>(0, (int a, _SeedFood f) => a + f.calories);
  int get totalSodium =>
      foods.fold<int>(0, (int a, _SeedFood f) => a + f.sodiumMg);
  double get totalSugar =>
      foods.fold<double>(0, (double a, _SeedFood f) => a + f.sugarG);

  DietEntriesCompanion companion(String date) => DietEntriesCompanion.insert(
    id: 'seed-diet-$date-$slug',
    date: date,
    mealType: mealType,
    timeLabel: timeLabel,
    foodsJson: jsonEncode(<Map<String, Object?>>[
      for (final _SeedFood f in foods) f.toJson(),
    ]),
    totalCalories: totalCalories,
    sodiumMg: Value(totalSodium),
    sugarG: Value(totalSugar),
    aiComment: Value(aiComment),
    photoAsset: Value(photoAsset),
  );
}

const List<_SeedMeal> _historyBreakfasts = <_SeedMeal>[
  _SeedMeal(
    slug: 'breakfast',
    mealType: 'breakfast',
    timeLabel: '08:05',
    photoAsset: 'assets/images/diet-oatmeal-banana.jpeg',
    aiComment: '오트밀로 식이섬유를 챙긴 아침이에요.',
    foods: <_SeedFood>[
      _SeedFood(
        '오트밀',
        calories: 250,
        sodiumMg: 100,
        sugarG: 6,
        carbsG: 42,
        proteinG: 10,
        fatG: 6,
      ),
      _SeedFood(
        '바나나',
        calories: 105,
        sodiumMg: 1,
        sugarG: 14,
        carbsG: 27,
        proteinG: 1.3,
        fatG: 0.4,
      ),
    ],
  ),
  _SeedMeal(
    slug: 'breakfast',
    mealType: 'breakfast',
    timeLabel: '08:30',
    photoAsset: 'assets/images/diet-greek-yogurt-nuts.jpeg',
    aiComment: '단백질과 불포화지방을 고르게 섭취했어요.',
    foods: <_SeedFood>[
      _SeedFood(
        '그릭 요거트',
        calories: 170,
        sodiumMg: 75,
        sugarG: 7,
        carbsG: 8,
        proteinG: 18,
        fatG: 8,
      ),
      _SeedFood(
        '견과류',
        calories: 150,
        sodiumMg: 5,
        sugarG: 2,
        carbsG: 6,
        proteinG: 5,
        fatG: 13,
      ),
    ],
  ),
  _SeedMeal(
    slug: 'breakfast',
    mealType: 'breakfast',
    timeLabel: '07:50',
    photoAsset: 'assets/images/breakfast-scrambled-egg-strawberry.jpg',
    aiComment: '달걀 단백질에 과일로 비타민을 더했어요.',
    foods: <_SeedFood>[
      _SeedFood(
        '스크램블 에그',
        calories: 185,
        sodiumMg: 220,
        sugarG: 0.8,
        carbsG: 2,
        proteinG: 13,
        fatG: 14,
      ),
      _SeedFood(
        '딸기',
        calories: 32,
        sodiumMg: 1,
        sugarG: 5.5,
        carbsG: 8,
        proteinG: 0.5,
        fatG: 0.5,
      ),
    ],
  ),
];

const List<_SeedMeal> _historyLunches = <_SeedMeal>[
  _SeedMeal(
    slug: 'lunch',
    mealType: 'lunch',
    timeLabel: '12:30',
    photoAsset: 'assets/images/diet-chicken-salad.jpg',
    aiComment: '닭가슴살과 채소로 단백질·식이섬유를 챙겼어요.',
    foods: <_SeedFood>[
      _SeedFood(
        '닭가슴살 샐러드',
        calories: 315,
        sodiumMg: 395,
        sugarG: 10,
        carbsG: 19,
        proteinG: 34,
        fatG: 11.1,
      ),
    ],
  ),
  _SeedMeal(
    slug: 'lunch',
    mealType: 'lunch',
    timeLabel: '12:20',
    photoAsset: 'assets/images/diet-vegetable-bibimbap.jpg',
    aiComment: '야채가 풍부해요. 고추장을 줄이면 나트륨이 더 좋아져요.',
    foods: <_SeedFood>[
      _SeedFood(
        '야채비빔밥',
        calories: 610,
        sodiumMg: 900,
        sugarG: 12,
        carbsG: 92,
        proteinG: 20,
        fatG: 16,
      ),
    ],
  ),
  _SeedMeal(
    slug: 'lunch',
    mealType: 'lunch',
    timeLabel: '12:50',
    photoAsset: 'assets/images/lunch-jjamppong.jpg',
    aiComment: '국물 나트륨이 높은 날이에요. 국물은 남기는 편이 좋아요.',
    foods: <_SeedFood>[
      _SeedFood(
        '짬뽕',
        calories: 750,
        sodiumMg: 3200,
        sugarG: 8.5,
        carbsG: 107,
        proteinG: 29,
        fatG: 22.5,
      ),
    ],
  ),
  _SeedMeal(
    slug: 'lunch',
    mealType: 'lunch',
    timeLabel: '12:10',
    photoAsset: 'assets/images/diet-doenjang-rice.jpeg',
    aiComment: '집밥 한 상이에요. 찌개 국물만 조금 남겨 보세요.',
    foods: <_SeedFood>[
      _SeedFood(
        '된장찌개',
        calories: 300,
        sodiumMg: 1300,
        sugarG: 5,
        carbsG: 18,
        proteinG: 24,
        fatG: 15,
      ),
      _SeedFood(
        '밥',
        calories: 310,
        sodiumMg: 5,
        sugarG: 0.7,
        carbsG: 67,
        proteinG: 6,
        fatG: 2.5,
      ),
    ],
  ),
];

const List<_SeedMeal> _historyDinners = <_SeedMeal>[
  _SeedMeal(
    slug: 'dinner',
    mealType: 'dinner',
    timeLabel: '18:40',
    photoAsset: 'assets/images/diet-salmon-brown-rice.jpeg',
    aiComment: '연어의 지방과 현미밥의 복합 탄수화물 조합이 좋아요.',
    foods: <_SeedFood>[
      _SeedFood(
        '연어구이',
        calories: 395,
        sodiumMg: 505,
        sugarG: 9,
        carbsG: 19,
        proteinG: 35,
        fatG: 19,
      ),
      _SeedFood(
        '현미밥',
        calories: 280,
        sodiumMg: 5,
        sugarG: 0,
        carbsG: 58,
        proteinG: 6,
        fatG: 2,
      ),
    ],
  ),
  _SeedMeal(
    slug: 'dinner',
    mealType: 'dinner',
    timeLabel: '19:10',
    photoAsset: 'assets/images/diet-doenjang-rice.jpeg',
    aiComment: '포만감은 좋지만 국물 나트륨이 높은 편이에요.',
    foods: <_SeedFood>[
      _SeedFood(
        '된장찌개',
        calories: 300,
        sodiumMg: 1300,
        sugarG: 5,
        carbsG: 18,
        proteinG: 24,
        fatG: 15,
      ),
      _SeedFood(
        '밥',
        calories: 310,
        sodiumMg: 5,
        sugarG: 0.7,
        carbsG: 67,
        proteinG: 6,
        fatG: 2.5,
      ),
    ],
  ),
  _SeedMeal(
    slug: 'dinner',
    mealType: 'dinner',
    timeLabel: '18:20',
    photoAsset: 'assets/images/diet-chicken-salad.jpg',
    aiComment: '가볍게 마무리한 저녁이에요.',
    foods: <_SeedFood>[
      _SeedFood(
        '닭가슴살 샐러드',
        calories: 315,
        sodiumMg: 395,
        sugarG: 10,
        carbsG: 19,
        proteinG: 34,
        fatG: 11.1,
      ),
      _SeedFood(
        '고구마',
        calories: 130,
        sodiumMg: 20,
        sugarG: 6.5,
        carbsG: 30,
        proteinG: 2,
        fatG: 0.2,
      ),
    ],
  ),
];

const _SeedMeal _historySnack = _SeedMeal(
  slug: 'snack',
  mealType: 'snack',
  timeLabel: '15:40',
  photoAsset: 'assets/images/snack-coffee-nuts.jpg',
  aiComment: '당류가 낮고 건강한 지방을 채운 간식이에요.',
  foods: <_SeedFood>[
    _SeedFood(
      '아이스 아메리카노',
      calories: 10,
      sodiumMg: 5,
      sugarG: 0,
      carbsG: 2,
      proteinG: 0.5,
      fatG: 0,
    ),
    _SeedFood(
      '견과류 한 봉',
      calories: 90,
      sodiumMg: 2,
      sugarG: 3,
      carbsG: 1,
      proteinG: 2,
      fatG: 8,
    ),
  ],
);

/// 큐레이션 사흘 앞의 과거 식단. `offset` 은 오늘로부터의 일수(3 부터).
///
/// 날짜마다 조합을 돌려 값이 달라지게 한다 — 모든 날이 같으면 주간·월간 추이가
/// 직선이 되어 기간 뷰가 아무것도 말해 주지 않는다. 7일마다 한 번은 저녁을
/// 비우고(늦은 저녁 미기록), 11일마다 한 번은 하루를 통째로 비운다 — "기록이
/// 없는 날"도 데모에 남아 있어야 그 빈 화면이 맞게 동작하는지 볼 수 있다.
List<DietEntriesCompanion> _historyDietEntries(DateTime now) {
  final entries = <DietEntriesCompanion>[];
  for (int offset = 3; offset < 3 + kDemoDietHistoryDays; offset++) {
    if (offset % 11 == 0) continue;
    final String date = _fmtDate(now.subtract(Duration(days: offset)));
    entries.add(
      _historyBreakfasts[offset % _historyBreakfasts.length].companion(date),
    );
    entries.add(
      _historyLunches[offset % _historyLunches.length].companion(date),
    );
    if (offset % 7 != 6) {
      entries.add(
        _historyDinners[offset % _historyDinners.length].companion(date),
      );
    }
    if (offset % 3 == 0) entries.add(_historySnack.companion(date));
  }
  return entries;
}

/// 한 주의 운동 세션 한 벌. `minutes` 는 요일별 유산소·근력·스트레칭 분이다.
const List<(String day, int cardio, int strength, int stretching)>
_historyWeekPattern =
    <(String, int, int, int)>[
      ('월', 30, 10, 5),
      ('화', 40, 0, 10),
      ('수', 0, 0, 0),
      ('목', 35, 20, 5),
      ('금', 45, 0, 10),
      ('토', 25, 30, 15),
      ('일', 20, 0, 10),
    ];

/// 지난 주들의 운동 세션. 주마다 강도를 조금씩 달리해(`scale`) 주간 비교가
/// 의미를 갖게 한다. 이번 주는 큐레이션 값을 쓰므로 `weeksAgo` 는 1 부터다.
List<ExerciseSessionsCompanion> _historyExerciseSessions(DateTime now) {
  final sessions = <ExerciseSessionsCompanion>[];
  final DateTime thisMonday = _mondayOfThisWeek(now);
  for (int weeksAgo = 1; weeksAgo <= kDemoExerciseHistoryWeeks; weeksAgo++) {
    final String weekStart = _fmtDate(
      thisMonday.subtract(Duration(days: 7 * weeksAgo)),
    );
    // 오래된 주일수록 조금 적게 — 데모에서 "요즘 늘고 있다"로 읽힌다.
    final double scale = 1 - (weeksAgo * 0.12);
    for (final (String day, int cardio, int strength, int stretching)
        in _historyWeekPattern) {
      void add(String type, int minutes, int caloriesPerMin) {
        final int scaled = (minutes * scale).round();
        if (scaled <= 0) return;
        sessions.add(
          ExerciseSessionsCompanion.insert(
            id: 'seed-ex-$weekStart-$day-$type',
            weekStart: weekStart,
            dayLabel: day,
            type: type,
            minutes: scaled,
            calories: scaled * caloriesPerMin,
          ),
        );
      }

      add('cardio', cardio, 7);
      add('strength', strength, 5);
      add('stretching', stretching, 3);
    }
  }
  return sessions;
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _mondayOfThisWeek(DateTime now) {
  final weekday = now.weekday; // 1 = Mon ... 7 = Sun
  return DateTime(now.year, now.month, now.day - (weekday - 1));
}
