import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';

/// Idempotent seeder for the trainer app's local DB. Runs at bootstrap.
///
/// **Flag.** `AppKeyValues['trainer_seeded_v1']` stores the date string
/// (`YYYY-MM-DD`) the seed last ran with. Behaviour mirrors the user
/// app's date-aware seeder (see the user app's `seed_data.dart`):
///
/// - `flag == today` → no-op (already seeded for today).
/// - otherwise (first boot or date rolled over) → wipe every
///   `seed-`-prefixed row and re-insert, sliding the trainer's schedule
///   onto today so the 스케줄 탭 is never empty on a later calendar day.
///
/// **User data is preserved.** Only rows whose `id` starts with `seed-`
/// are wiped, so anything added at runtime (e.g. a trainer's chat reply,
/// which gets a non-`seed-` id) survives re-seeding.
///
/// Source data mirrors the On-Care Figma trainer mock
/// (`TRAINER_CLIENTS` / `TRAINER_SCHEDULE`).
Future<void> seedIfEmpty(AppDatabase db) async {
  final today = ymd(DateTime.now());

  if (await db.readValue('trainer_seeded_v1') == today) return;

  // A fixed, ancient anchor for seed chat timestamps. Using a constant
  // (not DateTime.now()) keeps seed messages ordered before ANY reply
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

    // ---- Re-insert clients + their nested data ----
    for (final client in _clients) {
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
              caloriesToday: client.calories,
              sodiumMg: client.sodiumMg,
              sugarG: client.sugarG,
              lastRoutine: client.lastRoutine,
              weekCompletionJson: jsonEncode(client.weekCompletion),
              sortOrder: Value(client.id),
            ),
          );

      await db.batch((Batch b) {
        b.insertAll(db.clientDietEntries, <ClientDietEntriesCompanion>[
          for (var i = 0; i < client.diet.length; i++)
            ClientDietEntriesCompanion.insert(
              id: 'seed-diet-${client.id}-$i',
              clientId: 'seed-client-${client.id}',
              meal: client.diet[i].meal,
              items: client.diet[i].items,
              calories: client.diet[i].calories,
              sodiumMg: client.diet[i].sodiumMg,
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

        b.insertAll(db.clientRoutineHistory, <ClientRoutineHistoryCompanion>[
          for (var i = 0; i < client.history.length; i++)
            ClientRoutineHistoryCompanion.insert(
              id: 'seed-history-${client.id}-$i',
              clientId: 'seed-client-${client.id}',
              dateLabel: client.history[i].dateLabel,
              label: client.history[i].label,
              completionRate: client.history[i].completionRate,
              exercisesJson: jsonEncode(client.history[i].exercises),
              clientFeedback: Value(client.history[i].clientFeedback),
              trainerNote: Value(client.history[i].trainerNote),
              sortOrder: Value(i),
            ),
        ]);

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
              createdAt: chatEpoch.add(Duration(minutes: i)),
            ),
        ]);
      });
    }

    // ---- Trainer's schedule for today ----
    await db.batch((Batch b) {
      b.insertAll(db.trainerScheduleEntries, <TrainerScheduleEntriesCompanion>[
        for (var i = 0; i < _schedule.length; i++)
          TrainerScheduleEntriesCompanion.insert(
            id: 'seed-schedule-$i',
            date: today,
            time: _schedule[i].time,
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
    await db.putValue('trainer_seeded_v1', today);
  });
}

// ---------------------------------------------------------------------------
// Seed data (from On-Care_figma/src/app/App.tsx — TRAINER_CLIENTS /
// TRAINER_SCHEDULE). Kept as plain Dart structures for readability.
// ---------------------------------------------------------------------------

class _Meal {
  const _Meal(this.meal, this.items, this.calories, this.sodiumMg);
  final String meal;
  final String items;
  final int calories;
  final int sodiumMg;
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
  const _Chat(this.sender, this.text, this.timeLabel);
  final String sender; // trainer|client
  final String text;
  final String timeLabel;
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
    required this.diet,
    required this.aiRoutine,
    required this.history,
    required this.chat,
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
  final int sugarG;
  final String lastRoutine;
  final List<int> weekCompletion;
  final List<_Meal> diet;
  final List<_Routine> aiRoutine;
  final List<_History> history;
  final List<_Chat> chat;
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

const List<_Client> _clients = <_Client>[
  _Client(
    id: 1,
    name: '김민수',
    avatar: '김',
    goal: '혈압 관리 · 체중 감량',
    lastMessage: '오늘 식단 전송됐어요',
    lastTime: '방금',
    active: true,
    calories: 1420,
    sodiumMg: 2100,
    sugarG: 45,
    lastRoutine: '오늘',
    weekCompletion: <int>[100, 67, 100, 0, 100, 67, 100],
    diet: <_Meal>[
      _Meal('아침', '오트밀, 바나나', 315, 380),
      _Meal('점심', '닭가슴살 샐러드, 현미밥', 620, 890),
      _Meal('저녁', '두부찌개, 잡곡밥', 485, 830),
    ],
    aiRoutine: <_Routine>[
      _Routine('저강도 유산소 (걷기)', 30, '유산소', '혈압 안정에 효과적'),
      _Routine('하체 스트레칭', 15, '스트레칭', '혈액순환 개선'),
      _Routine('코어 강화', 10, '근력', '기초대사량 향상'),
    ],
    history: <_History>[
      _History(
        dateLabel: '7/12 (오늘)',
        label: 'PT 세션 · 트레이너 지도',
        completionRate: 100,
        exercises: <String>['레그프레스 3세트', '레그컬 3세트', '하체 스트레칭'],
        clientFeedback: '무릎이 좀 당겼지만 트레이너님 덕분에 잘 마쳤어요 😊',
        trainerNote: '무릎 가동범위 체크 필요. 다음 세션 중량 조절 예정.',
      ),
      _History(
        dateLabel: '7/10',
        label: 'AI 루틴 · 자율 운동',
        completionRate: 67,
        exercises: <String>['걷기 30분 ✓', '코어 강화 10분 ✓', '스트레칭 ✗ (생략)'],
        clientFeedback: '스트레칭은 시간이 없어서 못 했어요',
        trainerNote: '',
      ),
      _History(
        dateLabel: '7/8',
        label: 'AI 루틴 · 자율 운동',
        completionRate: 100,
        exercises: <String>['걷기 30분 ✓', '코어 강화 10분 ✓', '하체 스트레칭 15분 ✓'],
        clientFeedback: '오늘은 다 했어요! 뿌듯해요 💪',
        trainerNote: '',
      ),
    ],
    chat: <_Chat>[
      _Chat(
        'trainer',
        '민수님, AI 식단 분석 잘 받았어요 👍 오늘 나트륨이 목표치를 좀 넘었는데 어떠셨어요?',
        '18:10',
      ),
      _Chat('client', '찌개 먹을 때 국물을 많이 마셨나봐요 😅', '18:13'),
      _Chat('trainer', '그렇군요! 오늘 PT 후에 부상이나 불편한 데는 없으셨나요?', '18:14'),
      _Chat('client', '무릎이 가볍게 당기긴 했는데 괜찮아요', '18:16'),
      _Chat(
        'trainer',
        '확인했어요. AI가 오늘 식단 기반으로 유산소 루틴을 추천했는데, 무릎 상태 감안해서 런닝 대신 걷기로 조정해서 보낼게요. 다음 PT 때 봐요 💪',
        '18:18',
      ),
    ],
  ),
  _Client(
    id: 2,
    name: '이지수',
    avatar: '이',
    goal: '체력 강화 · 다이어트',
    lastMessage: '루틴 받았어요, 감사합니다!',
    lastTime: '1시간 전',
    active: true,
    calories: 1680,
    sodiumMg: 1800,
    sugarG: 38,
    lastRoutine: '어제',
    weekCompletion: <int>[67, 100, 100, 100, 100, 0, 0],
    diet: <_Meal>[
      _Meal('아침', '그릭요거트, 과일', 280, 200),
      _Meal('점심', '현미밥, 불고기, 나물', 750, 980),
      _Meal('저녁', '연어 샐러드', 650, 620),
    ],
    aiRoutine: <_Routine>[
      _Routine('인터벌 런닝', 25, '유산소', '체지방 연소 효율↑'),
      _Routine('스쿼트 3세트', 15, '근력', '하체 근력 강화'),
      _Routine('플랭크', 10, '근력', '코어 안정화'),
    ],
    history: <_History>[
      _History(
        dateLabel: '7/11 (어제)',
        label: 'AI 루틴 · 자율 운동',
        completionRate: 100,
        exercises: <String>['인터벌 런닝 25분 ✓', '스쿼트 3세트 ✓', '플랭크 10분 ✓'],
        clientFeedback: '런닝이 힘들었는데 다 했어요! 숨이 많이 찼어요',
        trainerNote: '심폐지구력 향상 중. 다음 주 런닝 강도 소폭 올릴 예정.',
      ),
      _History(
        dateLabel: '7/9',
        label: 'PT 세션 · 트레이너 지도',
        completionRate: 100,
        exercises: <String>['데드리프트 3세트', '런지 3세트', '코어 서킷'],
        clientFeedback: '데드리프트 자세 교정 도움 많이 됐어요!',
        trainerNote: '',
      ),
      _History(
        dateLabel: '7/7',
        label: 'AI 루틴 · 자율 운동',
        completionRate: 67,
        exercises: <String>['런닝 25분 ✓', '스쿼트 ✓', '플랭크 ✗ (피로)'],
        clientFeedback: '마지막 플랭크는 너무 지쳐서 못 했어요',
        trainerNote: '',
      ),
    ],
    chat: <_Chat>[
      _Chat(
        'trainer',
        '지수님, AI 운동 데이터 수신했어요 — 오늘 인터벌 런닝 25분 완료! 컨디션은 어때요?',
        '20:05',
      ),
      _Chat('client', '생각보다 괜찮았어요. 숨이 금방 차더라고요 😮‍💨', '20:08'),
      _Chat(
        'trainer',
        '심폐 지구력 올라가는 과정이에요 💪 AI 분석 보니까 당류는 목표 안에 있고, 루틴 다음 주부터 근력 비중 늘려볼게요. 식단도 AI 추천 참고해서 업데이트해 드릴게요',
        '20:10',
      ),
    ],
  ),
  _Client(
    id: 3,
    name: '박성호',
    avatar: '박',
    goal: '근력 향상',
    lastMessage: '이번 주 운동 못했어요...',
    lastTime: '3일 전',
    active: false,
    calories: 2100,
    sodiumMg: 2400,
    sugarG: 55,
    lastRoutine: '5일 전',
    weekCompletion: <int>[0, 33, 100, 0, 0, 0, 0],
    diet: <_Meal>[
      _Meal('아침', '계란 3개, 토스트', 480, 520),
      _Meal('점심', '짜장면', 890, 1200),
      _Meal('저녁', '삼겹살, 쌈채소', 730, 680),
    ],
    aiRoutine: <_Routine>[
      _Routine('벤치프레스 4세트', 20, '근력', '상체 근력 목표'),
      _Routine('데드리프트 3세트', 15, '근력', '전신 근력 향상'),
      _Routine('유산소 쿨다운', 10, '유산소', '나트륨 배출 지원'),
    ],
    history: <_History>[
      _History(
        dateLabel: '7/7',
        label: 'PT 세션 · 트레이너 지도',
        completionRate: 100,
        exercises: <String>['벤치프레스 4세트', '인클라인 덤벨 3세트', '트라이셉스 딥'],
        clientFeedback: '가슴이 많이 타는 느낌이었어요. 좋았어요!',
        trainerNote: '벤치 중량 62.5kg → 65kg 도전 가능. 다음 PT 때 시도 예정.',
      ),
      _History(
        dateLabel: '7/5',
        label: 'AI 루틴 · 자율 운동',
        completionRate: 33,
        exercises: <String>['벤치프레스 ✓', '데드리프트 ✗', '유산소 ✗'],
        clientFeedback: '회사 일이 생겨서 벤치만 하고 나왔어요',
        trainerNote: '',
      ),
      _History(
        dateLabel: '7/3',
        label: 'AI 루틴 · 자율 운동',
        completionRate: 0,
        exercises: <String>['벤치프레스 ✗', '데드리프트 ✗', '유산소 ✗'],
        clientFeedback: '못 갔어요 😓',
        trainerNote: '',
      ),
    ],
    chat: <_Chat>[
      _Chat('trainer', '성호님, 이번 주 운동 기록이 AI 쪽에서 안 잡히는데 몸은 괜찮으세요?', '월 09:00'),
      _Chat('client', '이번 주 일이 너무 많아서 못 갔어요 😓', '월 09:03'),
      _Chat(
        'trainer',
        '이해해요! 대신 AI 식단 분석 보니까 나트륨이 좀 높더라고요. 주말에 30분 걷기라도 하면 도움 돼요. AI가 그에 맞는 루틴 다시 짜줬으니까 앱에서 확인해보세요 🙂',
        '월 09:07',
      ),
    ],
  ),
];

const List<_Slot> _schedule = <_Slot>[
  _Slot(
    time: '10:00',
    clientName: '김민수',
    type: '1:1 PT',
    durationMinutes: 60,
    status: '완료',
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
    type: '1:1 PT',
    durationMinutes: 50,
    status: '완료',
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
    status: '공백',
    note: '',
    program: <Map<String, Object?>>[],
  ),
  _Slot(
    time: '15:00',
    clientName: '박성호',
    type: '1:1 PT',
    durationMinutes: 60,
    status: '예정',
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
    clientName: '신규 회원',
    type: '상담',
    durationMinutes: 30,
    status: '예정',
    note: '',
    program: <Map<String, Object?>>[],
  ),
  _Slot(
    time: '19:00',
    clientName: '',
    type: '',
    durationMinutes: 0,
    status: '공백',
    note: '',
    program: <Map<String, Object?>>[],
  ),
];
