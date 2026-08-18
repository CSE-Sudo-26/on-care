import 'dart:convert';

import 'package:demo_fixture/demo_fixture.dart';
import 'package:drift/drift.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/core/utils/clock.dart';

// The roster itself is bulky enough to drown the seeding logic, so it
// lives next door. `part` keeps the `_Client` family private to this
// library rather than making the shapes public just to split a file.
part 'seed_clients.dart';

/// Idempotent seeder for the trainer app's local DB. Runs at bootstrap.
///
/// **Flag.** `AppKeyValues['trainer_seeded_v18']` stores the date string
/// (`YYYY-MM-DD`) the seed last ran with. Bump the version suffix
/// whenever the seeded *content* changes — otherwise a browser that
/// already seeded today keeps the old data until the date rolls over.
///
/// Behaviour mirrors the user app's date-aware seeder (see the user
/// app's `seed_data.dart`):
///
/// - `flag == today` → no-op (already seeded for today).
/// - otherwise (first boot or date rolled over) → wipe every
///   `seed-`-prefixed row and re-insert, sliding the trainer's schedule
///   onto today so the 스케줄 탭 is never empty on a later calendar day.
///
/// 김민수(`seed-client-1`)의 하루는 이 파일이 만들지 않는다. 그는 사용자 앱의
/// 데모 계정(`user-demo`)과 같은 사람이라 두 앱을 나란히 놓고 시연하는데, 예전에는
/// 두 앱과 백엔드가 각자 알고리즘으로 그의 과거를 만들어서 같은 날짜의 숫자가 서로
/// 달랐다(#757). 그의 식단·이행률·날짜별 이력은 공유 픽스처에서 오고, 나머지 고객은
/// 아래 생성기(`_dailyMetrics`)가 그대로 만든다.
///
/// The flag is `_v18` (was `_v16`): 끼니마다 탄단지와 사진이 채워졌다(#819) — 열량만
/// 있고 영양소가 0 이면 식단 탭이 근거 없이 숫자만 보여 주고, 사진이 없으면
/// 이 제품의 핵심인 사진 인식을 데모에서 확인할 수 없다. 올리지 않으면
/// 오늘 이미 접속한 브라우저는 날짜가 넘어갈 때까지 옛 값을 그대로 쓴다.
/// `_v13` 은 요일마다 다른 루틴을 넣었다: each weekday now gets its own routine
/// so a week no longer repeats one workout (#754). `_v12` first carried that day's
/// exercise list for the report's 요일별 상세 (#754). `_v11` reached 12 weeks
/// back so the '최근 4주' card stays full while moving into the past (#752).
/// `_v10` first added dated daily history
/// so past weeks render (#752) — without a bump, anyone who opened the app
/// today would keep rows with no history behind them. `_v9` anchored the
/// weekly series onto weekdays, and every client now carries a weekly
/// 칼로리·당류 series for the metric-selectable trend chart (#746) —
/// without a bump, anyone who opened the app today would keep rows whose
/// new columns are still the empty default. `_v8` preserved 김민수's
/// 17.8g sugar for #565, `_v7` aligned his diet for #527, `_v6` added
/// client diet macros, and `_v5` had grown
/// 김민수's thread from five messages
/// to fifteen so the member and trainer demos tell the same story (#543).
/// `_v4` had bumped `_v3` when the roster grew from three clients to
/// fifteen. Without a bump, anyone who already opened the app today would
/// keep the old rows until the date rolled over — the same reason `_v2`
/// existed (it backfilled `sodiumWeekJson` after that column was added,
/// review PR 247).
///
/// **User data is preserved.** Only rows whose `id` starts with `seed-`
/// are wiped, so anything added at runtime (e.g. a trainer's chat reply,
/// which gets a non-`seed-` id) survives re-seeding.
///
/// The schedule mirrors the On-Care Figma trainer mock
/// (`TRAINER_SCHEDULE`); the roster started there and was extended into
/// the spread documented in `seed_clients.dart`. Note the schedule stays
/// at six slots on purpose: fifteen clients on the books does not mean
/// fifteen sessions in one day.
///
/// [clock] is the moment this seeding is anchored to. Production leaves it
/// out and gets the real one; tests pin it, because what lands in the week
/// depends on the weekday — a series is placed relative to today and
/// anything before Monday belongs to last week. Pinned dates are the only
/// way to assert that rule in both directions instead of on whichever day
/// the suite happens to run (#826).
Future<void> seedIfEmpty(
  AppDatabase db, {
  DemoFixture? fixture,
  DateTime? clock,
}) async {
  final DateTime now = clock ?? nowKst();
  final today = ymd(now);
  // 주간 계열을 요일 자리에 놓기 위한 오늘의 인덱스(월=0).
  final todayIndex = now.weekday - 1;

  if (await db.readValue('trainer_seeded_v18') == today) return;

  // 김민수의 하루는 픽스처가 정한다 — 이 앱은 날짜에 붙여 저장하기만 한다(#757).
  final _FixtureClient fixtureClient = _FixtureClient(
    (fixture ?? DemoFixture.load()).daysFor(now),
    todayIndex,
  );

  // A fixed, ancient anchor for seed chat timestamps. Using a constant
  // (not nowKst()) keeps seed messages ordered before ANY reply
  // added at runtime — including after a later-day re-seed, where a fresh
  // `now()` base would otherwise sort new seed rows *after* a preserved
  // runtime reply.
  final chatEpoch = DateTime.utc(2000, 1, 1);

  // First boot, or the date rolled over. Wipe + re-insert + flag all run
  // in ONE transaction: if any insert fails, the whole thing rolls back
  // to the prior state instead of leaving the old seed deleted with
  // nothing to replace it (which would show an empty app until the next
  // date rollover).
  await db.transaction(() async {
    // ---- Wipe existing seed rows (seed-% only; user rows survive) ----
    await (db.delete(
      db.trainerClients,
    )..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.clientDietEntries,
    )..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.clientAiRoutines,
    )..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.clientRoutineHistory,
    )..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.clientChatMessages,
    )..where((t) => t.id.like('seed-%'))).go();
    await (db.delete(
      db.trainerScheduleEntries,
    )..where((t) => t.id.like('seed-%'))).go();
    // 날짜별 이력은 id 가 없다(고객+날짜가 키다) — 고객 id 로 지운다.
    await (db.delete(
      db.clientDailyMetrics,
    )..where((t) => t.clientId.like('seed-%'))).go();

    // ---- Re-insert clients + their nested data ----
    for (final client in _clients) {
      // 김민수는 픽스처가 정한다. 나머지 고객은 이 파일의 값 그대로다.
      final bool fromFixture = client.id == _fixtureClientId;

      await db
          .into(db.trainerClients)
          .insert(
            TrainerClientsCompanion.insert(
              id: 'seed-client-${client.id}',
              name: client.name,
              avatar: client.avatar,
              goal: client.goal,
              lastMessage: client.lastMessage,
              lastTime: client.lastTime,
              active: Value(client.active),
              caloriesToday: fromFixture
                  ? fixtureClient.today.calories
                  : client.calories,
              sodiumMg: fromFixture
                  ? fixtureClient.today.sodiumMg
                  : client.sodiumMg,
              sugarG: fromFixture ? fixtureClient.today.sugarG : client.sugarG,
              carbsG: Value(
                fromFixture ? fixtureClient.carbsToday : client.carbsG,
              ),
              proteinG: Value(
                fromFixture ? fixtureClient.proteinToday : client.proteinG,
              ),
              fatG: Value(fromFixture ? fixtureClient.fatToday : client.fatG),
              lastRoutine: client.lastRoutine,
              weekCompletionJson: jsonEncode(
                fromFixture
                    ? fixtureClient.completionWeek
                    : _upToToday(client.weekCompletion, todayIndex),
              ),
              sodiumWeekJson: Value(
                jsonEncode(
                  fromFixture
                      ? fixtureClient.sodiumWeek
                      : _onWeekdays(client.sodiumWeek, todayIndex),
                ),
              ),
              caloriesWeekJson: Value(
                jsonEncode(
                  fromFixture
                      ? fixtureClient.caloriesWeek
                      : _onWeekdays(client.caloriesWeek, todayIndex),
                ),
              ),
              sugarWeekJson: Value(
                jsonEncode(
                  fromFixture
                      ? fixtureClient.sugarWeek
                      : _onWeekdays(client.sugarWeek, todayIndex),
                ),
              ),
              sortOrder: Value(client.id),
            ),
          );

      final List<_Meal> diet = fromFixture ? fixtureClient.diet : client.diet;

      await db.batch((Batch b) {
        b.insertAll(db.clientDietEntries, <ClientDietEntriesCompanion>[
          for (var i = 0; i < diet.length; i++)
            ClientDietEntriesCompanion.insert(
              id: 'seed-diet-${client.id}-$i',
              clientId: 'seed-client-${client.id}',
              meal: diet[i].meal,
              items: diet[i].items,
              calories: diet[i].calories,
              sodiumMg: diet[i].sodiumMg,
              carbsG: Value(diet[i].carbsG),
              proteinG: Value(diet[i].proteinG),
              fatG: Value(diet[i].fatG),
              photoAsset: Value(diet[i].photoAsset),
              sortOrder: Value(i),
            ),
        ]);

        b.insertAll(db.clientAiRoutines, <ClientAiRoutinesCompanion>[
          for (var i = 0; i < client.aiRoutine.length; i++)
            ClientAiRoutinesCompanion.insert(
              id: 'seed-airoutine-${client.id}-$i',
              clientId: 'seed-client-${client.id}',
              name: client.aiRoutine[i].name,
              minutes: client.aiRoutine[i].minutes,
              type: client.aiRoutine[i].type,
              reason: client.aiRoutine[i].reason,
              sortOrder: Value(i),
            ),
        ]);

        final List<_History> history = fromFixture
            ? fixtureClient.history
            : client.history;
        b.insertAll(db.clientRoutineHistory, <ClientRoutineHistoryCompanion>[
          for (var i = 0; i < history.length; i++)
            ClientRoutineHistoryCompanion.insert(
              id: 'seed-history-${client.id}-$i',
              clientId: 'seed-client-${client.id}',
              dateLabel: history[i].dateLabel,
              label: history[i].label,
              completionRate: history[i].completionRate,
              exercisesJson: jsonEncode(history[i].exercises),
              clientFeedback: Value(history[i].clientFeedback),
              trainerNote: Value(history[i].trainerNote),
              sortOrder: Value(i),
            ),
        ]);

        b.insertAll(
          db.clientDailyMetrics,
          fromFixture
              ? fixtureClient.dailyMetrics().toList(growable: false)
              : _dailyMetrics(client, now).toList(growable: false),
        );

        b.insertAll(db.clientChatMessages, <ClientChatMessagesCompanion>[
          for (var i = 0; i < client.chat.length; i++)
            ClientChatMessagesCompanion.insert(
              id: 'seed-chat-${client.id}-$i',
              clientId: 'seed-client-${client.id}',
              sender: client.chat[i].sender,
              body: client.chat[i].text,
              timeLabel: client.chat[i].timeLabel,
              // Anchored at the fixed ancient epoch (oldest first, a
              // minute apart) so any runtime reply — and any preserved
              // reply from a previous day — always sorts after the seed.
              // dayIndex 는 여러 날에 걸친 스레드를 실제로 날짜가 다른
              // 시각으로 만든다 — 라벨만 갈라 두면 화면이 하루로 묶는다.
              createdAt: chatEpoch.add(
                Duration(days: client.chat[i].dayIndex, minutes: i),
              ),
            ),
        ]);
      });
    }

    // ---- Read markers for threads that start answered ----
    // The marker is the newest client message's rowid, exactly what
    // `markThreadRead` writes — so opening the thread later is a no-op
    // rather than a second, different value.
    for (final client in _clients.where((c) => c.threadHandled)) {
      final id = 'seed-client-${client.id}';
      final row = await db
          .customSelect(
            'SELECT MAX(rowid) AS r FROM client_chat_messages '
            "WHERE client_id = ?1 AND sender = 'client'",
            variables: <Variable<Object>>[Variable<String>(id)],
          )
          .getSingleOrNull();
      final marker = row?.read<int?>('r');
      if (marker != null) await db.putValue('chat_read_$id', '$marker');
    }

    // ---- Trainer's schedule for today ----
    // 스케줄은 고객을 id 로 참조한다(#386). 슬롯 데이터는 이름만 들고 있으므로
    // 시드 고객 목록에서 id 를 유도한다 — 매핑을 따로 손으로 관리하면 이름을
    // 고칠 때 또 어긋난다. 미등록(상담)·공백 슬롯은 이름이 없어 null 로 남는다.
    final seedClientIdByName = <String, String>{
      for (final _Client c in _clients) c.name: 'seed-client-${c.id}',
    };
    await db.batch((Batch b) {
      b.insertAll(db.trainerScheduleEntries, <TrainerScheduleEntriesCompanion>[
        for (var i = 0; i < _schedule.length; i++)
          TrainerScheduleEntriesCompanion.insert(
            id: 'seed-schedule-$i',
            date: today,
            time: _schedule[i].time,
            clientId: Value(seedClientIdByName[_schedule[i].clientName]),
            clientName: Value(_schedule[i].clientName),
            type: Value(_schedule[i].type),
            durationMinutes: Value(_schedule[i].durationMinutes),
            status: _schedule[i].status,
            note: Value(_schedule[i].note),
            programJson: Value(jsonEncode(_schedule[i].program)),
            sortOrder: Value(i),
          ),
      ]);
    });

    // ---- Mark seeded (inside the txn so it commits atomically) ----
    await db.putValue('trainer_seeded_v18', today);
  });
}

// ---------------------------------------------------------------------------
// Seed data (from On-Care_figma/src/app/App.tsx — TRAINER_CLIENTS /
// TRAINER_SCHEDULE). Kept as plain Dart structures for readability.
// ---------------------------------------------------------------------------

class _Meal {
  const _Meal(
    this.meal,
    this.items,
    this.calories,
    this.sodiumMg, {
    this.carbsG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.photoAsset,
  });
  final String meal;
  final String items;
  final int calories;
  final int sodiumMg;
  final double carbsG;
  final double proteinG;
  final double fatG;

  /// 데모에서 이 끼니로 보여 줄 번들 이미지. 없으면 사진 없이 그린다. (#819)
  final String? photoAsset;
}

class _Routine {
  const _Routine(this.name, this.minutes, this.type, this.reason);
  final String name;
  final int minutes;
  final String type;
  final String reason;
}

class _History {
  const _History({
    required this.dateLabel,
    required this.label,
    required this.completionRate,
    required this.exercises,
    required this.clientFeedback,
    required this.trainerNote,
  });
  final String dateLabel;
  final String label;
  final int completionRate;
  final List<String> exercises;
  final String clientFeedback;
  final String trainerNote;
}

class _Chat {
  const _Chat(this.sender, this.text, this.timeLabel, {this.dayIndex = 0});
  final String sender; // trainer|client
  final String text;
  final String timeLabel;

  /// 며칠째 대화인가 (0 = 스레드의 첫 날). 여러 날에 걸친 스레드에서만 쓴다.
  ///
  /// `timeLabel` 은 화면에 보일 문자열일 뿐이라 날짜 정보가 아니다. 전에는
  /// 라벨만 '화/수' 로 갈라 놓고 `createdAt` 은 전부 몇 분 안에 몰려 있어서,
  /// 날짜로 묶으려는 쪽(대화 중간의 AI 분석 안내)에서 하루로 보였다.
  final int dayIndex;
}


/// 데모가 들고 있는 주 수(이번 주 포함). '최근 4주' 카드는 보고 있는 주에서
/// 3주를 더 거슬러 읽으므로, 뒤로 이동한 만큼 더 있어야 카드가 꽉 찬다.
/// 12주면 8주 전까지 뒤로 가도 빈 칸이 없다. 백엔드 시드도 같은 값이다(#752).
const int _demoHistoryWeeks = 12;

/// 주마다 곱하는 계수. 과거로 갈수록 값이 조금씩 다르게 보이도록 고정된 수를
/// 돌려 쓴다 — 난수를 쓰면 재시딩마다 이력이 바뀌어 어제 본 화면과 달라진다.
/// 과거 주를 흔드는 계수 — **지표마다 따로** 둔다.
///
/// 예전에는 넷이 한 계수를 나눠 쓰고 폭도 ±11% 뿐이라, 12주 내내 나트륨은 늘
/// 초과하고 칼로리·당류는 늘 목표 안이었다. 목표선도 색도 지표마다 한쪽
/// 경우만 보여 줬다. 사람은 그렇게 살지 않는다 — 회식이 몰린 주는 칼로리도
/// 당류도 같이 넘고, 코칭이 먹힌 주는 나트륨이 목표 안으로 들어온다.
///
/// index 0 은 이번 주다. 반드시 1.0 — 이번 주 값은 카드에 보이는 그대로여야
/// 한다.
const List<double> _calorieFactors = <double>[
  1.0,
  0.92,
  1.28, // 회식이 몰린 주 — 목표를 넘긴다.
  0.88,
  1.04,
  0.95,
  1.13,
];

const List<double> _sodiumFactors = <double>[
  1.0,
  0.96,
  1.14,
  0.82, // 코칭이 먹힌 주 — 목표 안으로 들어온다.
  1.07,
  0.78,
  1.10,
];

const List<double> _sugarFactors = <double>[
  1.0,
  1.12,
  1.55, // 칼로리를 넘긴 그 주. 단 것도 같이 늘었다.
  0.88,
  1.30,
  0.96,
  1.42,
];

/// 이행률은 좁게 흔든다. 폭을 넓히면 100 에 붙어 잘려(clamp) 여러 주가 같은
/// 값이 되고, 오히려 변화가 사라진다.
const List<double> _completionFactors = <double>[
  1.0,
  0.94,
  1.08,
  0.9,
  1.05,
  0.97,
  1.11,
];
/// 고객의 날짜별 하루 집계. 이번 주는 카드에 보이는 값 그대로, 지난 주들은
/// **같은 요일 자리에** 같은 기록 습관으로 채운다.
///
/// 기록이 드문 고객(휴면·첫 주)은 과거에도 드물게 남는다 — 과거 주만 갑자기
/// 성실해지면 화면이 그 고객의 이야기와 어긋난다. 기록이 하나도 없는 고객은
/// 과거에도 없다.
/// 픽스처가 정하는 고객. 김민수(1) 하나다 — 그만 사용자 앱의 데모 계정과 같은
/// 사람이라 두 앱의 숫자를 맞춰야 한다(#757). 나머지 고객은 이 파일이 만든다.
const int _fixtureClientId = 1;

/// 픽스처가 말하는 김민수를, 이 앱의 테이블이 기대하는 모양으로 옮긴다.
///
/// 여기에 계산은 없다 — 합계도 이행률도 픽스처 쪽 모델이 이미 갖고 있고, 이 클래스는
/// 그것을 요일 자리에 놓거나 행 모양으로 바꾸기만 한다.
class _FixtureClient {
  _FixtureClient(this.days, this.todayIndex)
    : today = days.last,
      _thisWeek = days.where((FixtureDay d) => d.weekStart == days.last.weekStart)
          .toList(growable: false);

  final List<FixtureDay> days;
  final int todayIndex;
  final FixtureDay today;
  final List<FixtureDay> _thisWeek;

  double get carbsToday => _sumToday((FixtureMeal m) => m.carbsG);
  double get proteinToday => _sumToday((FixtureMeal m) => m.proteinG);
  double get fatToday => _sumToday((FixtureMeal m) => m.fatG);

  double _sumToday(double Function(FixtureMeal) pick) {
    final double total = today.meals.fold<double>(
      0,
      (double sum, FixtureMeal m) => sum + pick(m),
    );
    return (total * 10).round() / 10;
  }

  /// 오늘 끼니. 트레이너 화면은 끼니 이름과 음식 목록을 한 줄로 읽는다.
  List<_Meal> get diet => <_Meal>[
    for (final FixtureMeal meal in today.meals)
      _Meal(
        _mealLabel(meal.mealType),
        meal.foods.map((FixtureFood f) => f.name).join(', '),
        meal.calories,
        meal.sodiumMg,
        carbsG: meal.carbsG,
        proteinG: meal.proteinG,
        fatG: meal.fatG,
        // 공유 픽스처가 이미 끼니마다 사진을 가리키고 있다(#757). 회원 앱만
        // 쓰던 그 값을 트레이너 데모도 함께 읽는다(#819).
        photoAsset: meal.photoAsset,
      ),
  ];

  /// 고객 상세의 최근 운동 이력. 가까운 날부터, 운동이 있던 날만.
  List<_History> get history => <_History>[
    for (final FixtureDay day in days.reversed.where(
      (FixtureDay d) => d.exercises.isNotEmpty,
    ).take(3))
      _History(
        dateLabel: _historyLabel(day),
        label: day.routineLabel,
        completionRate: day.completion,
        exercises: <String>[
          for (final FixtureExercise e in day.exercises) e.label,
        ],
        clientFeedback: day.clientFeedback,
        trainerNote: day.trainerNote,
      ),
  ];

  /// 날짜 라벨. 예전에는 `'7/12 (오늘)'` 처럼 박아 두어 날이 바뀌어도 그대로였다.
  String _historyLabel(FixtureDay day) {
    final DateTime date = DateTime.parse(day.date);
    final String base = '${date.month}/${date.day}';
    return day.date == today.date ? '$base (오늘)' : base;
  }

  List<int> get caloriesWeek => _week<int>(0, (FixtureDay d) => d.calories);
  List<int> get sodiumWeek => _week<int>(0, (FixtureDay d) => d.sodiumMg);
  List<double> get sugarWeek => _week<double>(0.0, (FixtureDay d) => d.sugarG);
  List<int> get completionWeek => _week<int>(0, (FixtureDay d) => d.completion);

  /// 이번 주 값을 월→일 자리에 놓는다. 아직 오지 않은 요일은 0 이다 — 넣으면 주간
  /// 추이 그래프가 빈 날을 막대로 그리고 주 평균도 실제보다 높아진다(#752).
  List<T> _week<T extends num>(T zero, T Function(FixtureDay) pick) {
    final List<T> week = List<T>.filled(7, zero);
    for (final FixtureDay day in _thisWeek) {
      final int index = DateTime.parse(day.date).weekday - 1;
      if (index <= todayIndex) week[index] = pick(day);
    }
    return week;
  }

  /// 날짜별 하루 집계. 기록이 아예 없는 날은 넣지 않는다.
  Iterable<ClientDailyMetricsCompanion> dailyMetrics() sync* {
    for (final FixtureDay day in days) {
      if (!day.hasRecord) continue;
      yield ClientDailyMetricsCompanion.insert(
        clientId: 'seed-client-$_fixtureClientId',
        date: day.date,
        completion: Value(day.completion),
        calories: Value(day.calories),
        sodiumMg: Value(day.sodiumMg),
        sugarG: Value(day.sugarG),
        exercisesJson: Value(
          jsonEncode(<String>[
            for (final FixtureExercise e in day.exercises) e.label,
          ]),
        ),
      );
    }
  }
}

/// 끼니 종류 → 화면에 쓰는 한국어 라벨.
String _mealLabel(String mealType) => switch (mealType) {
  'breakfast' => '아침',
  'lunch' => '점심',
  'dinner' => '저녁',
  _ => '간식',
};

Iterable<ClientDailyMetricsCompanion> _dailyMetrics(_Client client, DateTime now) sync* {
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final todayIndex = today.weekday - 1;

  for (var back = 0; back < _demoHistoryWeeks; back++) {
    final weekMonday = monday.subtract(Duration(days: 7 * back));
    final calorieFactor = _calorieFactors[back % _calorieFactors.length];
    final sodiumFactor = _sodiumFactors[back % _sodiumFactors.length];
    final sugarFactor = _sugarFactors[back % _sugarFactors.length];
    final doneFactor = _completionFactors[back % _completionFactors.length];
    // 이번 주는 오늘까지만, 지난 주들은 일요일까지 — 지난 주에 '아직 오지 않은
    // 요일'은 없다.
    final anchor = back == 0 ? todayIndex : 6;
    final calories = _onWeekdays(client.caloriesWeek, anchor);
    final sodium = _onWeekdays(client.sodiumWeek, anchor);
    final sugar = _onWeekdays(client.sugarWeek, anchor);
    final completion = client.weekCompletion;

    for (var day = 0; day < 7; day++) {
      final date = weekMonday.add(Duration(days: day));
      if (date.isAfter(today)) break;
      final cal = _scaled(calories[day], calorieFactor);
      final na = _scaled(sodium[day], sodiumFactor);
      final sg = day < sugar.length ? sugar[day] * sugarFactor : 0.0;
      final done = day < completion.length
          ? _scaled(completion[day], doneFactor).clamp(0, 100)
          : 0;
      if (cal == 0 && na == 0 && sg == 0 && done == 0) continue;
      yield ClientDailyMetricsCompanion.insert(
        clientId: 'seed-client-${client.id}',
        date: ymd(date),
        completion: Value(done),
        calories: Value(cal),
        sodiumMg: Value(na),
        sugarG: Value(double.parse((sg).toStringAsFixed(1))),
        exercisesJson: Value(
          jsonEncode(
            date == today
                ? _exercisesFor(client, done, today: true)
                : _routineFor(client.id, day, done),
          ),
        ),
      );
    }
  }
}

/// 이번 주는 값을 그대로 두고(계수 1) 과거 주만 흔든다.
int _scaled(num value, double factor) => (value * factor).round();

/// 요일마다 다른 루틴. 한 고객이 한 주 내내 같은 운동만 하면 화면이 복사본
/// 처럼 읽힌다 — 요일과 고객을 함께 돌려 서로 다른 조합이 나오게 한다.
const List<List<String>> _routinePool = <List<String>>[
  <String>['스쿼트 4세트', '런지 3세트', '레그컬 3세트'],
  <String>['벤치프레스 4세트', '푸시업 3세트', '덤벨 플라이 3세트'],
  <String>['데드리프트 4세트', '바벨 로우 3세트', '풀업 3세트'],
  <String>['숄더 프레스 4세트', '사이드 레터럴 3세트', '페이스 풀 3세트'],
  <String>['런닝 30분', '사이클 20분', '코어 서킷 10분'],
  <String>['레그프레스 4세트', '힙 쓰러스트 3세트', '카프 레이즈 3세트'],
  <String>['플랭크 3세트', '버피 3세트', '마운틴 클라이머 3세트'],
];

/// 그날의 운동 목록 — 이행률과 **맞게** ✓/✗ 를 붙인다.
///
/// 67% 인 날에 3개 모두 ✓ 인 목록을 붙이면 화면에서 "67%" 옆에 "3개 중 3개
/// 완료" 가 놓여 서로 다른 말을 한다(#754).
///
/// 오늘만은 고객의 큐레이션된 운동 기록을 그대로 쓴다 — 같은 날을 리포트와
/// 고객 상세의 운동 기록이 각각 다른 운동으로 보여 주면 안 된다.
List<String> _exercisesFor(_Client client, int completion, {bool today = false}) {
  if (completion <= 0) return const <String>[];
  if (today && client.history.isNotEmpty) {
    var best = client.history.first;
    for (final entry in client.history) {
      if ((entry.completionRate - completion).abs() <
          (best.completionRate - completion).abs()) {
        best = entry;
      }
    }
    return best.exercises;
  }
  return const <String>[];
}

/// 요일·고객으로 고른 루틴에 이행률만큼 ✓ 를 매긴다.
List<String> _routineFor(int clientId, int weekday, int completion) {
  if (completion <= 0) return const <String>[];
  final names = _routinePool[(clientId + weekday) % _routinePool.length];
  final done = (names.length * completion / 100).round().clamp(1, names.length);
  return <String>[
    for (var i = 0; i < names.length; i++)
      '${names[i]} ${i < done ? '✓' : '✗'}',
  ];
}

/// 아직 오지 않은 요일을 지운다.
///
/// 시드의 이행률 배열은 월→일 한 주치라, 그대로 쓰면 수요일에 열어도 주말이
/// 채워져 있다. 운동 추이 카드가 오지 않은 날을 막대로 그리고, 주 평균도
/// 그 날들을 포함해 실제보다 높게 나온다 — 화면은 비워 두고 평균만 포함하는
/// 어긋남이 여기서 생겼다(#752).
List<int> _upToToday(List<int> week, int todayIndex) => <int>[
  for (var i = 0; i < week.length; i++) i <= todayIndex ? week[i] : 0,
];

/// 시드의 "오래된→오늘" 계열을 **이번 주 월→일** 자리에 옮긴다.
///
/// 시드 배열은 마지막 값이 오늘이고 길이가 고객마다 다르다(기록이 끊긴
/// 고객이 있다). 화면은 이 값을 요일 라벨과 함께 그리므로, 오늘을 오늘 요일
/// 자리에 놓고 그 앞으로 하루씩 거슬러 채운다. 월요일보다 앞선 값은 지난
/// 주의 것이라 버리고, 기록이 없는 날과 아직 오지 않은 요일은 0 이다 —
/// 백엔드 `_daily_week` 와 같은 규칙이다(#746).
List<T> _onWeekdays<T extends num>(List<T> series, int todayIndex) {
  final zero = (0 is T ? 0 : 0.0) as T;
  final week = List<T>.filled(7, zero);
  for (var i = 0; i < series.length; i++) {
    final index = todayIndex - (series.length - 1 - i);
    if (index >= 0) week[index] = series[i];
  }
  return week;
}

class _Client {
  const _Client({
    required this.id,
    required this.name,
    required this.avatar,
    required this.goal,
    required this.lastMessage,
    required this.lastTime,
    required this.active,
    required this.calories,
    required this.sodiumMg,
    required this.sugarG,
    required this.lastRoutine,
    required this.weekCompletion,
    required this.sodiumWeek,
    required this.caloriesWeek,
    required this.sugarWeek,
    required this.diet,
    required this.aiRoutine,
    required this.history,
    required this.chat,
    this.threadHandled = false,
  });
  final int id;
  final String name;
  final String avatar;
  final String goal;
  final String lastMessage;
  final String lastTime;
  final bool active;
  final int calories;
  final int sodiumMg;
  final double sugarG;
  final String lastRoutine;
  final List<int> weekCompletion;
  final List<int> sodiumWeek;

  /// 나트륨과 같은 창의 칼로리·당류 추이. 지표 선택형 그래프가 쓴다(#746).
  final List<int> caloriesWeek;
  final List<double> sugarWeek;
  final List<_Meal> diet;
  double get carbsG => diet.fold(0, (total, meal) => total + meal.carbsG);
  double get proteinG => diet.fold(0, (total, meal) => total + meal.proteinG);
  double get fatG => diet.fold(0, (total, meal) => total + meal.fatG);
  final List<_Routine> aiRoutine;
  final List<_History> history;
  final List<_Chat> chat;

  /// Whether the demo starts with this thread already answered and read.
  ///
  /// Unread is "client messages with no read marker", so a thread that
  /// merely ends with a trainer message still counts every reply the
  /// member sent. Without this flag the demo opens with all three members
  /// waiting, which is not the state we want to show.
  final bool threadHandled;
}

class _Slot {
  const _Slot({
    required this.time,
    required this.clientName,
    required this.type,
    required this.durationMinutes,
    required this.status,
    required this.note,
    required this.program,
  });
  final String time;
  final String clientName;
  final String type;
  final int durationMinutes;
  final String status; // 완료|예정|공백
  final String note;
  final List<Map<String, Object?>> program; // {name,sets,reps,weight}
}

const List<_Slot> _schedule = <_Slot>[
  _Slot(
    time: '10:00',
    clientName: '김민수',
    type: SessionType.personalTraining,
    durationMinutes: 60,
    status: ScheduleStatus.done,
    note: '무릎 컨디션 양호. 레그프레스 중량 소폭 증가 가능.',
    program: <Map<String, Object?>>[
      <String, Object?>{
        'name': '레그프레스',
        'sets': 3,
        'reps': '12회',
        'weight': '80kg',
      },
      <String, Object?>{
        'name': '레그컬',
        'sets': 3,
        'reps': '12회',
        'weight': '40kg',
      },
      <String, Object?>{
        'name': '카프레이즈',
        'sets': 3,
        'reps': '20회',
        'weight': '자체중량',
      },
      <String, Object?>{
        'name': '하체 스트레칭',
        'sets': 1,
        'reps': '10분',
        'weight': '-',
      },
    ],
  ),
  _Slot(
    time: '12:00',
    clientName: '이지수',
    type: SessionType.personalTraining,
    durationMinutes: 50,
    status: ScheduleStatus.done,
    note: '데드리프트 자세 안정적. 다음 세션 60kg 도전.',
    program: <Map<String, Object?>>[
      <String, Object?>{
        'name': '데드리프트',
        'sets': 4,
        'reps': '8회',
        'weight': '55kg',
      },
      <String, Object?>{
        'name': '루마니안 데드리프트',
        'sets': 3,
        'reps': '10회',
        'weight': '40kg',
      },
      <String, Object?>{'name': '플랭크', 'sets': 3, 'reps': '45초', 'weight': '-'},
      <String, Object?>{
        'name': '코어 서킷',
        'sets': 2,
        'reps': '12회',
        'weight': '-',
      },
    ],
  ),
  _Slot(
    time: '14:00',
    clientName: '',
    type: '',
    durationMinutes: 0,
    status: ScheduleStatus.gap,
    note: '',
    program: <Map<String, Object?>>[],
  ),
  _Slot(
    time: '15:00',
    clientName: '박성호',
    type: SessionType.personalTraining,
    durationMinutes: 60,
    status: ScheduleStatus.upcoming,
    note: '',
    program: <Map<String, Object?>>[
      <String, Object?>{
        'name': '벤치프레스',
        'sets': 4,
        'reps': '8회',
        'weight': '65kg',
      },
      <String, Object?>{
        'name': '인클라인 덤벨 프레스',
        'sets': 3,
        'reps': '10회',
        'weight': '26kg',
      },
      <String, Object?>{
        'name': '트라이셉스 딥',
        'sets': 3,
        'reps': '12회',
        'weight': '-',
      },
    ],
  ),
  _Slot(
    time: '17:00',
    clientName: '신규 고객',
    type: SessionType.consultation,
    durationMinutes: 30,
    status: ScheduleStatus.upcoming,
    note: '',
    program: <Map<String, Object?>>[],
  ),
  _Slot(
    time: '19:00',
    clientName: '',
    type: '',
    durationMinutes: 0,
    status: ScheduleStatus.gap,
    note: '',
    program: <Map<String, Object?>>[],
  ),
];
