import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';

// The roster itself is bulky enough to drown the seeding logic, so it
// lives next door. `part` keeps the `_Client` family private to this
// library rather than making the shapes public just to split a file.
part 'seed_clients.dart';

/// Idempotent seeder for the trainer app's local DB. Runs at bootstrap.
///
/// **Flag.** `AppKeyValues['trainer_seeded_v5']` stores the date string
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
/// The flag is `_v5` (was `_v4`): 김민수's thread grew from five messages
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
Future<void> seedIfEmpty(AppDatabase db) async {
  final today = ymd(DateTime.now());

  if (await db.readValue('trainer_seeded_v5') == today) return;

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
              sodiumWeekJson: Value(jsonEncode(client.sodiumWeek)),
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
    await db.putValue('trainer_seeded_v5', today);
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
  final int sugarG;
  final String lastRoutine;
  final List<int> weekCompletion;
  final List<int> sodiumWeek;
  final List<_Meal> diet;
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
