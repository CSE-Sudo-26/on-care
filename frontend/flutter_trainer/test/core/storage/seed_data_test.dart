import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';

String _todayString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('seedIfEmpty', () {
    test('first run seeds the roster with its related data', () async {
      await seedIfEmpty(db);

      final clients = await db.select(db.trainerClients).get();
      expect(clients.length, 15);
      expect(
        clients.map((c) => c.name).toSet().length,
        15,
        reason: '이름이 겹치면 addClient 의 중복 검사와 스케줄 폴백이 어긋난다',
      );

      // Every client must be coachable and chartable, whatever else their
      // fixture is demonstrating: the 코칭 탭 reads the routine list and
      // the completion bars index all seven days.
      for (final c in clients) {
        final routines = await (db.select(
          db.clientAiRoutines,
        )..where((t) => t.clientId.equals(c.id))).get();
        expect(routines, isNotEmpty, reason: '${c.name}: AI 루틴이 없으면 코칭 탭이 빈다');
        expect(
          (jsonDecode(c.weekCompletionJson) as List<Object?>).length,
          7,
          reason: '${c.name}: 완료율 막대는 7일을 인덱싱한다',
        );
      }

      expect(await db.select(db.clientChatMessages).get(), isNotEmpty);
      expect(await db.readValue('trainer_seeded_v10'), _todayString());
    });

    test(
      '김민수 sugar matches the member mock and survives drift roundtrip',
      () async {
        await seedIfEmpty(db);

        final minsu = await (db.select(
          db.trainerClients,
        )..where((c) => c.id.equals('seed-client-1'))).getSingle();
        // frontend/flutter's current MockDietRepository daily total is 17.8g.
        expect(minsu.sugarG, 17.8);
      },
    );

    // The roster is a fixture for the *charts*, not just the list — its
    // whole point is that every state the console can render is reachable
    // by clicking around the demo. Assert that spread directly, so
    // flattening the data back out to fifteen similar weeks fails here
    // rather than silently making half the UI unreachable.
    test('the roster covers the states the console has to render', () async {
      await seedIfEmpty(db);
      final clients = await db.select(db.trainerClients).get();

      List<int> sodiumWeek(TrainerClientRow c) =>
          (jsonDecode(c.sodiumWeekJson) as List<Object?>)
              .map((e) => (e! as num).toInt())
              .toList();
      List<int> week(TrainerClientRow c) =>
          (jsonDecode(c.weekCompletionJson) as List<Object?>)
              .map((e) => e! as int)
              .toList();
      bool low(TrainerClientRow c) {
        final recorded = week(c).where((d) => d > 0).toList();
        if (recorded.isEmpty) return false;
        return recorded.reduce((a, b) => a + b) / recorded.length < 60;
      }

      List<double> caloriesWeek(TrainerClientRow c) =>
          (jsonDecode(c.caloriesWeekJson) as List<Object?>)
              .map((e) => (e! as num).toDouble())
              .toList();
      List<double> sugarWeek(TrainerClientRow c) =>
          (jsonDecode(c.sugarWeekJson) as List<Object?>)
              .map((e) => (e! as num).toDouble())
              .toList();

      // 세 계열은 이번 주 월→일에 놓인다(#746). 화면이 요일 라벨과 함께
      // 그리므로 길이는 늘 7이고, 오늘 값은 오늘 요일 칸에 들어간다 — 카드의
      // 숫자와 그래프의 오늘 점이 같아야 한다.
      final todayIndex = DateTime.now().weekday - 1;
      for (final c in clients) {
        expect(
          <int>[
            sodiumWeek(c).length,
            caloriesWeek(c).length,
            sugarWeek(c).length,
          ],
          everyElement(7),
          reason: '${c.name} 주간 계열 길이',
        );
        expect(sodiumWeek(c)[todayIndex], c.sodiumMg, reason: c.name);
        expect(
          caloriesWeek(c)[todayIndex],
          c.caloriesToday.toDouble(),
          reason: c.name,
        );
        expect(sugarWeek(c)[todayIndex], c.sugarG, reason: c.name);
        // 아직 오지 않은 요일은 누구에게나 0.
        expect(
          sodiumWeek(c).skip(todayIndex + 1),
          everyElement(0),
          reason: c.name,
        );
      }
      // 당류는 소수를 잃지 않는다.
      expect(
        clients.where((c) => sugarWeek(c).any((v) => v != v.roundToDouble())),
        isNotEmpty,
        reason: '소수 당류를 가진 고객',
      );

      // 추이 모양: 지난 날을 모두 기록한 고객, 중간에 끊긴 고객, 하루만 있는
      // 고객, 하나도 없는 고객 — 각각 다른 화면을 탄다. 계열이 요일에 고정되면서
      // '꽉 찬 주'는 7일이 아니라 **오늘까지의 날 수**다.
      int recorded(TrainerClientRow c) =>
          sodiumWeek(c).where((v) => v > 0).length;
      final elapsed = todayIndex + 1;
      expect(clients.where((c) => recorded(c) == elapsed), isNotEmpty);
      expect(
        clients.where((c) => recorded(c) > 1 && recorded(c) < elapsed),
        isNotEmpty,
        reason: '기록이 끊긴 고객',
      );
      expect(clients.where((c) => recorded(c) == 1), isNotEmpty);
      expect(
        clients.where((c) => recorded(c) == 0),
        isNotEmpty,
        reason: '기록이 하나도 없는 고객',
      );

      // Alert combinations, including the two that are easy to lose.
      expect(
        clients.where((c) => c.sodiumMg > 2000 && !low(c)),
        isNotEmpty,
        reason: '나트륨만 초과',
      );
      expect(
        clients.where((c) => c.sodiumMg <= 2000 && low(c)),
        isNotEmpty,
        reason: '이행률만 저조',
      );
      expect(
        clients.where((c) => c.sodiumMg > 2000 && low(c)),
        isNotEmpty,
        reason: '복합 — 확인 필요 목록 맨 위에 오는 케이스',
      );
      expect(
        clients.where((c) => c.sodiumMg <= 2000 && !low(c) && c.sugarG <= 50),
        isNotEmpty,
        reason: '무알림 대조군이 없으면 배지가 항상 켜진 화면만 보게 된다',
      );
      expect(clients.where((c) => c.sugarG > 50), isNotEmpty, reason: '당류 경고');
      expect(clients.where((c) => !c.active), isNotEmpty, reason: '휴면');

      // A brand-new client: no meals, no history. `isLowCompletion` must
      // NOT flag an all-zero week, or day one reads as failure.
      final blank = clients.where((c) => recorded(c) == 0).first;
      expect(low(blank), isFalse);
      final meals = await (db.select(
        db.clientDietEntries,
      )..where((t) => t.clientId.equals(blank.id))).get();
      final history = await (db.select(
        db.clientRoutineHistory,
      )..where((t) => t.clientId.equals(blank.id))).get();
      expect(meals, isEmpty, reason: '식단 빈 상태 렌더링 경로');
      expect(history, isEmpty, reason: '운동 기록 빈 상태 렌더링 경로');
    });

    test('schedule seeds onto today (never empty on a later day)', () async {
      await seedIfEmpty(db);

      final schedule = await db.select(db.trainerScheduleEntries).get();
      expect(schedule, isNotEmpty);
      expect(
        schedule.every((s) => s.date == _todayString()),
        isTrue,
        reason: 'all schedule rows must slide onto today',
      );
      // Program JSON is well-formed for a PT session.
      final pt = schedule.firstWhere((s) => s.clientName == '김민수');
      expect(jsonDecode(pt.programJson), isA<List<Object?>>());
    });

    test('same-day re-run is a no-op (no duplicates)', () async {
      await seedIfEmpty(db);
      final before = await db.select(db.trainerClients).get();

      await seedIfEmpty(db);
      final after = await db.select(db.trainerClients).get();

      expect(after.length, before.length);
    });

    test('stale flag (different date) re-seeds schedule onto today', () async {
      await seedIfEmpty(db);
      await db.putValue('trainer_seeded_v10', '2020-01-01');

      await seedIfEmpty(db);

      final schedule = await db.select(db.trainerScheduleEntries).get();
      expect(schedule.every((s) => s.date == _todayString()), isTrue);
      expect(await db.readValue('trainer_seeded_v10'), _todayString());
    });

    test(
      'seed chat messages are in the past so runtime replies sort after',
      () async {
        await seedIfEmpty(db);

        // All seed messages must predate "now" (they use past timestamps),
        // otherwise a reply added right after boot could interleave.
        final now = DateTime.now();
        final all = await db.select(db.clientChatMessages).get();
        final seeded = all.where((m) => m.id.startsWith('seed-')).toList();
        expect(seeded, isNotEmpty);
        expect(
          seeded.every((m) => m.createdAt.isBefore(now)),
          isTrue,
          reason: 'seed chat messages must not use future timestamps',
        );

        // A reply added now sorts last within its client's thread.
        await db
            .into(db.clientChatMessages)
            .insert(
              ClientChatMessagesCompanion.insert(
                id: 'chat-runtime-order',
                clientId: 'seed-client-1',
                sender: 'trainer',
                body: '방금 보낸 답장',
                timeLabel: '21:30',
                createdAt: DateTime.now(),
              ),
            );

        final thread = await (db.select(
          db.clientChatMessages,
        )..where((m) => m.clientId.equals('seed-client-1'))).get();
        thread.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        expect(thread.last.id, 'chat-runtime-order');
      },
    );

    test('per-meal sums match each client\'s daily totals', () async {
      // The diet summary tiles read the client row's totals while the
      // meal cards read ClientDietEntries — the two sources must agree.
      await seedIfEmpty(db);

      final clients = await db.select(db.trainerClients).get();
      expect(clients, isNotEmpty);
      for (final client in clients) {
        final meals = await (db.select(
          db.clientDietEntries,
        )..where((t) => t.clientId.equals(client.id))).get();
        final sodiumSum = meals.fold<int>(0, (s, m) => s + m.sodiumMg);
        final kcalSum = meals.fold<int>(0, (s, m) => s + m.calories);
        final carbsSum = meals.fold<double>(0, (s, m) => s + m.carbsG);
        final proteinSum = meals.fold<double>(0, (s, m) => s + m.proteinG);
        final fatSum = meals.fold<double>(0, (s, m) => s + m.fatG);
        expect(
          sodiumSum,
          client.sodiumMg,
          reason: '${client.name}: meal sodium must sum to the daily total',
        );
        expect(
          kcalSum,
          client.caloriesToday,
          reason: '${client.name}: meal calories must sum to the daily total',
        );
        expect(
          carbsSum,
          client.carbsG,
          reason: '${client.name}: carbs mismatch',
        );
        expect(
          proteinSum,
          client.proteinG,
          reason: '${client.name}: protein mismatch',
        );
        expect(fatSum, client.fatG, reason: '${client.name}: fat mismatch');
      }
    });

    test(
      'a same-day upgrade under an older flag re-seeds exactly once',
      () async {
        final today = _todayString();

        // Simulate an older build: already seeded TODAY under a previous
        // flag, plus a runtime (non-seed) client that must survive.
        await db.putValue('trainer_seeded_v9', today);
        await db
            .into(db.trainerClients)
            .insert(
              TrainerClientsCompanion.insert(
                id: 'client-runtime-1',
                name: '최수진',
                avatar: '최',
                goal: '체중 감량',
                lastMessage: '아직 대화가 없어요',
                lastTime: '-',
                caloriesToday: 0,
                sodiumMg: 0,
                sugarG: 0,
                lastRoutine: '-',
                weekCompletionJson: '[0,0,0,0,0,0,0]',
                // sodiumWeekJson stays at its blank v2 default.
              ),
            );

        // The `_v2` flag is absent, so this upgrade re-seeds exactly once
        // even though `_v1 == today` — the old flag alone would skip it and
        // leave sodium trends blank all day (review PR 247).
        await seedIfEmpty(db);

        final clients = await db.select(db.trainerClients).get();
        // The runtime client survived.
        expect(clients.any((c) => c.id == 'client-runtime-1'), isTrue);
        // The seed clients were (re-)inserted with a real 7-day trend.
        final minsu = clients.firstWhere((c) => c.id == 'seed-client-1');
        final week = jsonDecode(minsu.sodiumWeekJson) as List<Object?>;
        expect(week.length, 7);
        expect(week.any((v) => (v as num) > 0), isTrue);

        expect(await db.readValue('trainer_seeded_v10'), today);
      },
    );

    test('user-added (non-seed) chat messages survive a re-seed', () async {
      await seedIfEmpty(db);

      // A trainer reply added at runtime — no seed- prefix.
      await db
          .into(db.clientChatMessages)
          .insert(
            ClientChatMessagesCompanion.insert(
              id: 'chat-runtime-1',
              clientId: 'seed-client-1',
              sender: 'trainer',
              body: '다음 세션 때 봐요!',
              timeLabel: '21:00',
              createdAt: DateTime.now(),
            ),
          );

      // Force a re-seed.
      await db.putValue('trainer_seeded_v10', '2020-01-01');
      await seedIfEmpty(db);

      final chat = await db.select(db.clientChatMessages).get();
      expect(
        chat.any((m) => m.id == 'chat-runtime-1'),
        isTrue,
        reason: 'rows without a seed- prefix must never be wiped',
      );

      // After the re-seed, the preserved runtime reply must STILL sort
      // after the (re-inserted) seed messages — the fixed epoch anchor
      // guarantees this even though the re-seed ran on a later day.
      final thread = chat.where((m) => m.clientId == 'seed-client-1').toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(thread.last.id, 'chat-runtime-1');
    });
  });
}
