import 'dart:convert';

import 'package:demo_fixture/demo_fixture.dart';
import 'package:drift/drift.dart';

import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/utils/clock.dart';

/// 하루 단위 코치 문구(날짜 → 문장)를 담는 키-값 키.
///
/// 끼니가 아니라 **하루**에 붙는 문장이라 `dietEntries` 행에 둘 자리가 없고, 시연용
/// 날짜 셋뿐이라 테이블을 새로 만들 이유도 없다. 시드가 쓰고 로컬 인터셉터가 읽는다.
///
/// 날짜별로 키를 나누지 않고 한 키에 묶는 이유: 시드는 날이 바뀌면 앞으로 미끄러지는데,
/// 키를 날짜마다 만들면 지난 날짜 키가 계속 쌓인다. 한 키를 통째로 덮어쓰면 그 문제가 없다.
const String kDietDayMessagesKey = 'diet_day_messages';

/// 데모가 채우는 날들은 이제 이 앱이 정하지 않는다.
///
/// 김민수(`user-demo`)는 트레이너 앱의 `seed-client-1` 과 같은 사람이라 두 앱을
/// 나란히 놓고 시연하는데, 예전에는 두 앱과 백엔드가 각자 알고리즘으로 그의 과거를
/// 만들어서 같은 날짜의 숫자가 서로 달랐다(#757). 지금은 셋 다 같은 픽스처를 읽는다
/// — 며칠치를 채울지도 픽스처가 갖고 있다(`DemoFixture.historyWeeks`).

/// Date-aware idempotent seeder. Runs at bootstrap.
///
/// **Flag format (v4+).** `AppKeyValues['seeded_v17']` stores the
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
Future<void> seedIfEmpty(AppDatabase db, {DemoFixture? fixture}) async {
  final now = nowKst();
  final today = _fmtDate(now);

  final seedDate = await db.readValue('seeded_v17');
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
  // v17: 식단·운동이 공유 픽스처에서 온다(#757). 올리지 않으면 오늘 이미 시드된
  // 설치가 예전 값을 들고 있어 트레이너 앱과 나란히 놓았을 때 숫자가 어긋난다.
  await db.deleteValue('seeded_v16');
  // Also clear the curated KV advice so re-seed state is fully reset: this
  // version re-writes it below, but if a later seed drops or renames the key
  // an existing install would otherwise keep the stale text forever.
  await db.deleteValue('dashboard_ai_advice');

  // 김민수의 하루는 픽스처가 정한다 — 이 앱은 날짜에 붙여 저장하기만 한다(#757).
  final DemoFixture demo = fixture ?? DemoFixture.load();
  final List<FixtureDay> days = demo.daysFor(now);

  await db.transaction(() async {
    // ---- 식단 ----
    // 끼니 단위로 저장한다. 하루 합계는 화면이 이 행들을 더해 만들므로, 끼니 화면과
    // 일별 집계가 구조적으로 어긋날 수 없다.
    await db.batch((Batch b) {
      b.insertAll(db.dietEntries, <DietEntriesCompanion>[
        for (final FixtureDay day in days)
          for (final FixtureMeal meal in day.meals)
            DietEntriesCompanion.insert(
              // 시연 중 화면에서 지목하는 행만 픽스처가 id 를 못 박아 둔다.
              // 나머지는 날짜에서 만든다.
              id: meal.rowId ?? 'seed-diet-${day.date}-${meal.mealType}',
              date: day.date,
              mealType: meal.mealType,
              timeLabel: meal.timeLabel,
              foodsJson: meal.foodsJson(),
              totalCalories: meal.calories,
              sodiumMg: Value(meal.sodiumMg),
              sugarG: Value(meal.sugarG),
              aiComment: Value(meal.aiComment),
              photoAsset: Value(meal.photoAsset),
            ),
      ]);
    });

    // ---- 운동 세션 ----
    // **실제로 한** 운동만 쌓는다. 못 한 항목까지 넣으면 이행률은 67% 인데 주간
    // 운동 시간은 100% 인 날이 나온다.
    //
    // 하루에 같은 종류가 둘일 수 있어(PT 날의 레그프레스·레그컬은 둘 다 근력)
    // 종류로 합친다 — 주간 활동 그래프가 하루·종류당 한 칸을 그린다.
    await db.batch((Batch b) {
      b.insertAll(db.exerciseSessions, <ExerciseSessionsCompanion>[
        for (final FixtureDay day in days)
          for (final MapEntry<String, ({int minutes, int calories})> entry
              in _byType(day.doneExercises).entries)
            ExerciseSessionsCompanion.insert(
              id: 'seed-ex-${day.date}-${entry.key}',
              weekStart: day.weekStart,
              dayLabel: day.dayLabel,
              type: entry.key,
              minutes: entry.value.minutes,
              calories: entry.value.calories,
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

  // 식단 탭의 하루 코치 문구. 문장을 가진 날(픽스처의 큐레이션 사흘)만 넣고, 그
  // 밖의 날짜는 인터셉터가 수치를 보고 만든 문구로 대신한다([kDietDayMessagesKey]).
  await db.putValue(
    kDietDayMessagesKey,
    jsonEncode(<String, String>{
      for (final FixtureDay day in days)
        if (day.dayMessage.isNotEmpty) day.date: day.dayMessage,
    }),
  );

  await db.putValue('seeded_v17', today);
}

/// 운동을 종류별로 합친다 — {종류: (분, 칼로리)}. 픽스처 순서를 유지한다.
Map<String, ({int minutes, int calories})> _byType(
  List<FixtureExercise> exercises,
) {
  final Map<String, ({int minutes, int calories})> totals =
      <String, ({int minutes, int calories})>{};
  for (final FixtureExercise exercise in exercises) {
    final ({int minutes, int calories}) prev =
        totals[exercise.type] ?? (minutes: 0, calories: 0);
    totals[exercise.type] = (
      minutes: prev.minutes + exercise.minutes,
      calories: prev.calories + exercise.calories,
    );
  }
  return totals;
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
