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
/// **Flag format (v4+).** `AppKeyValues['seeded_v16']` stores the
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

  final seedDate = await db.readValue('seeded_v16');
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
        // 시연에 쓰는 큐레이션 사흘. 음식 구성과 영양 수치는 히스토리와 같은
        // 템플릿에서 나오고, 여기서는 고정 id·시각·그날의 코치 문구만 덮어쓴다
        // — 수치를 두 벌로 두면 한쪽만 고쳤을 때 조용히 어긋난다(#677).
        _mealScrambledEggStrawberry.companion(
          today,
          id: 'seed-diet-breakfast',
          timeLabel: '08:20',
          aiComment:
              '단백질과 식이섬유의 깔끔한 조합으로, 소금 간과 기름만 조절하면 혈당과 혈압 모두 잡는 우수한 식단입니다.',
        ),
        _mealJjamppong.companion(
          today,
          id: 'seed-diet-lunch',
          timeLabel: '12:40',
          aiComment:
              '정제 면과 높은 나트륨으로 혈압·혈당 부담이 매우 크니, 국물은 남기고 야채 위주로 드시는 것이 좋습니다.',
        ),
        _mealCoffeeNuts.companion(
          today,
          id: 'seed-diet-snack',
          timeLabel: '15:30',
          aiComment: '당류와 칼로리가 낮고 견과류의 건강한 지방이 채워져 완벽한 간식입니다.',
        ),
        // 어제는 약속이 있던 날 — 하루 합이 2,380kcal · 2,261mg · 63.0g 으로
        // 칼로리와 당류가 목표(2,000kcal · 50g)를 넘는다. 목표선과 초과 색이
        // 실제로 동작하는지 시연에서 눈으로 확인하려면 넘긴 날이 하나는 있어야
        // 하고, **어제**여야 데모를 여는 날이 언제든 항상 화면에 들어온다.
        //
        // 트레이너 앱 데모(`flutter_trainer` 의 `seed_data.dart`)와 백엔드
        // 시드가 같은 합계를 쓴다. 두 앱을 나란히 놓고 시연하므로 한쪽만
        // 고치면 그 자리에서 티가 난다.
        _mealOatmealBanana.companion(
          yesterday,
          id: 'seed-diet-yesterday-breakfast',
          timeLabel: '08:10',
          aiComment: '오트밀로 식이섬유를 챙겼어요. 바나나가 들어가 당류는 다소 높은 편이에요.',
        ),
        _mealVegetableBibimbap.companion(
          yesterday,
          id: 'seed-diet-yesterday-lunch',
          timeLabel: '12:30',
          aiComment: '야채가 풍부한 비빔밥이에요. 고추장을 줄이면 나트륨을 더 조절할 수 있어요.',
        ),
        _mealSamgyeopsalDinner.companion(
          yesterday,
          id: 'seed-diet-yesterday-dinner',
        ),
        _mealCakeLatteSnack.companion(
          yesterday,
          id: 'seed-diet-yesterday-snack',
        ),
        _mealGreekYogurtNuts.companion(
          twoDaysAgo,
          id: 'seed-diet-two-days-ago-breakfast',
          timeLabel: '08:35',
          aiComment: '그릭 요거트의 단백질과 견과류의 불포화지방을 고르게 섭취했어요.',
        ),
        _mealVegetableBibimbap.companion(
          twoDaysAgo,
          id: 'seed-diet-two-days-ago-lunch',
          timeLabel: '12:20',
          aiComment: '야채가 풍부한 비빔밥이에요. 고추장을 줄이면 나트륨을 더 조절할 수 있어요.',
        ),
        _mealSalmonBrownRice.companion(
          twoDaysAgo,
          id: 'seed-diet-two-days-ago-dinner',
          timeLabel: '18:50',
          aiComment: '연어의 지방과 현미밥의 복합 탄수화물 조합이 좋아요.',
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

  await db.putValue('seeded_v16', today);
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

  /// 이 끼니를 [date] 의 행으로 만든다.
  ///
  /// [id]·[timeLabel]·[aiComment] 를 덮어쓸 수 있다. 시연에 쓰는 큐레이션
  /// 사흘은 고정 id(`seed-diet-lunch` 등)와 그날만의 코치 문구를 갖는데, **음식
  /// 구성과 영양 수치는 히스토리와 똑같다.** 덮어쓰기를 두어 수치는 한 곳에만
  /// 남기고 표현만 갈아 끼운다.
  DietEntriesCompanion companion(
    String date, {
    String? id,
    String? timeLabel,
    String? aiComment,
  }) => DietEntriesCompanion.insert(
    id: id ?? 'seed-diet-$date-$slug',
    date: date,
    mealType: mealType,
    timeLabel: timeLabel ?? this.timeLabel,
    foodsJson: jsonEncode(<Map<String, Object?>>[
      for (final _SeedFood f in foods) f.toJson(),
    ]),
    totalCalories: totalCalories,
    sodiumMg: Value(totalSodium),
    sugarG: Value(totalSugar),
    aiComment: Value(aiComment ?? this.aiComment),
    photoAsset: Value(photoAsset),
  );
}

/// 여러 끼니에 함께 쓰이는 음식. 끼니 상수마다 다시 적으면 이 변경이 없애려는
/// 중복이 그대로 남는다 — 한 곳에서만 고칠 수 있게 뽑아 둔다.
const _SeedFood _foodDoenjangJjigae = _SeedFood(
  '된장찌개',
  calories: 300,
  sodiumMg: 1300,
  sugarG: 5,
  carbsG: 18,
  proteinG: 24,
  fatG: 15,
);

const _SeedFood _foodRice = _SeedFood(
  '밥',
  calories: 310,
  sodiumMg: 5,
  sugarG: 0.7,
  carbsG: 67,
  proteinG: 6,
  fatG: 2.5,
);

const _SeedFood _foodChickenSalad = _SeedFood(
  '닭가슴살 샐러드',
  calories: 315,
  sodiumMg: 395,
  sugarG: 10,
  carbsG: 19,
  proteinG: 34,
  fatG: 11.1,
);

const _SeedMeal _mealOatmealBanana = _SeedMeal(
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
);

const _SeedMeal _mealGreekYogurtNuts = _SeedMeal(
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
);

const _SeedMeal _mealScrambledEggStrawberry = _SeedMeal(
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
);

const List<_SeedMeal> _historyBreakfasts = <_SeedMeal>[
  _mealOatmealBanana,
  _mealGreekYogurtNuts,
  _mealScrambledEggStrawberry,
];

const _SeedMeal _mealChickenSalad = _SeedMeal(
  slug: 'lunch',
  mealType: 'lunch',
  timeLabel: '12:30',
  photoAsset: 'assets/images/diet-chicken-salad.jpg',
  aiComment: '닭가슴살과 채소로 단백질·식이섬유를 챙겼어요.',
  foods: <_SeedFood>[_foodChickenSalad],
);

const _SeedMeal _mealVegetableBibimbap = _SeedMeal(
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
);

const _SeedMeal _mealJjamppong = _SeedMeal(
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
);

const _SeedMeal _mealDoenjangRiceLunch = _SeedMeal(
  slug: 'lunch',
  mealType: 'lunch',
  timeLabel: '12:10',
  photoAsset: 'assets/images/diet-doenjang-rice.jpeg',
  aiComment: '집밥 한 상이에요. 찌개 국물만 조금 남겨 보세요.',
  foods: <_SeedFood>[_foodDoenjangJjigae, _foodRice],
);

const List<_SeedMeal> _historyLunches = <_SeedMeal>[
  _mealChickenSalad,
  _mealVegetableBibimbap,
  _mealJjamppong,
  _mealDoenjangRiceLunch,
];

const _SeedMeal _mealSalmonBrownRice = _SeedMeal(
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
);

const _SeedMeal _mealDoenjangRiceDinner = _SeedMeal(
  slug: 'dinner',
  mealType: 'dinner',
  timeLabel: '19:10',
  photoAsset: 'assets/images/diet-doenjang-rice.jpeg',
  aiComment: '포만감은 좋지만 국물 나트륨이 높은 편이에요.',
  foods: <_SeedFood>[_foodDoenjangJjigae, _foodRice],
);

const _SeedMeal _mealChickenSaladSweetPotato = _SeedMeal(
  slug: 'dinner',
  mealType: 'dinner',
  timeLabel: '18:20',
  photoAsset: 'assets/images/diet-chicken-salad.jpg',
  aiComment: '가볍게 마무리한 저녁이에요.',
  foods: <_SeedFood>[
    _foodChickenSalad,
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
);

const List<_SeedMeal> _historyDinners = <_SeedMeal>[
  _mealSalmonBrownRice,
  _mealDoenjangRiceDinner,
  _mealChickenSaladSweetPotato,
];

const _SeedMeal _mealCoffeeNuts = _SeedMeal(
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

// ---- 약속이 있던 어제 ----------------------------------------------------
//
// 어제 하루만 칼로리·당류가 목표를 넘는다. 아침·점심은 평소대로 먹고 저녁에
// 약속이 있어 고기와 디저트가 얹힌 하루다 — 아래 두 끼가 그 몫이다.

const _SeedMeal _mealSamgyeopsalDinner = _SeedMeal(
  slug: 'dinner',
  mealType: 'dinner',
  timeLabel: '19:30',
  // 삼겹살 사진 에셋이 없어 가장 가까운 한식 상차림을 쓴다.
  photoAsset: 'assets/images/diet-doenjang-rice.jpeg',
  aiComment: '고기와 술이 함께여서 칼로리가 크게 올라갔어요. 다음 날은 가볍게 시작해 보세요.',
  foods: <_SeedFood>[
    _SeedFood(
      '삼겹살 2인분',
      calories: 620,
      sodiumMg: 880,
      sugarG: 1,
      carbsG: 2,
      proteinG: 42,
      fatG: 50,
    ),
    _foodRice,
    _SeedFood(
      '소주 1병',
      calories: 55,
      sodiumMg: 0,
      sugarG: 0,
      carbsG: 0,
      proteinG: 0,
      fatG: 0,
    ),
  ],
);

const _SeedMeal _mealCakeLatteSnack = _SeedMeal(
  slug: 'snack',
  mealType: 'snack',
  timeLabel: '21:10',
  photoAsset: 'assets/images/snack-coffee-nuts.jpg',
  aiComment: '디저트로 당류가 하루 목표를 넘었어요.',
  foods: <_SeedFood>[
    _SeedFood(
      '초코 케이크 한 조각',
      calories: 330,
      sodiumMg: 280,
      sugarG: 24,
      carbsG: 42,
      proteinG: 5,
      fatG: 15,
    ),
    _SeedFood(
      '카페라떼',
      calories: 100,
      sodiumMg: 95,
      sugarG: 5.3,
      carbsG: 10,
      proteinG: 5,
      fatG: 4,
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
    if (offset % 3 == 0) entries.add(_mealCoffeeNuts.companion(date));
  }
  return entries;
}

/// 한 주의 운동 세션 한 벌. `minutes` 는 요일별 유산소·근력·스트레칭 분이다.
const List<(String day, int cardio, int strength, int stretching)>
_historyWeekPattern = <(String, int, int, int)>[
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
