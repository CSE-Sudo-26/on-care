import 'dart:convert';
import 'dart:io';

import 'package:demo_fixture/demo_fixture.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/clock.dart';

/// 시드가 읽는 것과 같은 픽스처. 사용자 앱 테스트도 같은 파일을 본다 — 두 앱의
/// 단정이 같은 원본을 가리켜야 "같은 날짜, 같은 숫자"가 실제로 지켜진다(#757).
final DemoFixture _fixture = DemoFixture.parse(
  File('../../shared/demo_fixture/assets/kim_minsu.json').readAsStringSync(),
);

String _todayString() {
  final now = nowKst();
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
      expect(await db.readValue('trainer_seeded_v18'), _todayString());
    });

    test(
      '김민수 sugar matches the member mock and survives drift roundtrip',
      () async {
        await seedIfEmpty(db);

        final minsu = await (db.select(
          db.trainerClients,
        )..where((c) => c.id.equals('seed-client-1'))).getSingle();
        // 사용자 앱과 같은 픽스처에서 오는 값이다.
        expect(minsu.sugarG, 17.8);
      },
    );

    test('김민수의 날짜별 값이 픽스처와 같다', () async {
      // 사용자 앱도 같은 픽스처를 읽으므로, 이 단정이 곧 "두 앱을 나란히 놓고 같은
      // 날짜를 봐도 숫자가 같다"는 뜻이다(#757).
      await seedIfEmpty(db);

      final Map<String, FixtureDay> byDate = <String, FixtureDay>{
        for (final FixtureDay day in _fixture.daysFor(nowKst())) day.date: day,
      };

      final rows = await (db.select(
        db.clientDailyMetrics,
      )..where((t) => t.clientId.equals('seed-client-1'))).get();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        final FixtureDay day = byDate[row.date]!;
        expect(row.calories, day.calories, reason: '${row.date} 칼로리');
        expect(row.sodiumMg, day.sodiumMg, reason: '${row.date} 나트륨');
        expect(
          row.sugarG,
          closeTo(day.sugarG, 0.001),
          reason: '${row.date} 당류',
        );
        expect(row.completion, day.completion, reason: '${row.date} 이행률');
      }

      // 기록이 없는 날은 행 자체가 없어야 한다 — 0 으로 채우면 주 평균이 내려간다.
      final Set<String> seeded = rows.map((r) => r.date).toSet();
      final Iterable<String> blank = byDate.values
          .where((FixtureDay d) => !d.hasRecord)
          .map((FixtureDay d) => d.date);
      expect(blank, isNotEmpty, reason: '기록 없는 날이 픽스처에 있어야 이 검증이 뜻을 갖는다');
      for (final String date in blank) {
        expect(seeded, isNot(contains(date)), reason: '$date 는 기록이 없는 날이다');
      }
    });

    // The roster is a fixture for the *charts*, not just the list — its
    // whole point is that every state the console can render is reachable
    // by clicking around the demo. Assert that spread directly, so
    // flattening the data back out to fifteen similar weeks fails here
    // rather than silently making half the UI unreachable.
    test('the roster covers the states the console has to render', () async {
      // 시계를 고정한다. 이 테스트가 요구하는 스펙트럼("기록이 끊긴 고객" 등)은
      // 주가 얼마나 지났는지에 달려 있어, 실행한 날에 맡기면 주 초에는 존재할
      // 수 없다 — 월요일이면 모두에게 하루치뿐이다(#826).
      //
      // 목요일에 고정한다. 계열은 월요일 이전 값을 지난주로 버리므로(#746),
      // 네 가지 모양이 한 주 안에 모두 나타나려면 며칠이 지나 있어야 한다.
      // 2026-08-20 은 목요일이다.
      final pinned = DateTime(2026, 8, 20, 10);
      await seedIfEmpty(db, clock: pinned);
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
      final todayIndex = pinned.weekday - 1;
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

      // '최근 4주' 카드는 보고 있는 주에서 3주를 더 거슬러 읽는다. 과거로
      // 이동해도 카드가 꽉 차려면 그만큼 더 있어야 한다(#752).
      final full = clients.firstWhere(
        (c) => sodiumWeek(c).where((v) => v > 0).length > 3,
      );
      // 시드가 고정된 날짜 기준으로 만들어졌으므로, 얼마나 거슬러 올라가는지도
      // 그 날짜에서 센다. 실제 오늘로 재면 시드가 만들어진 주와 어긋나 CI 가
      // 도는 날에 따라 결과가 달라진다(#826).
      final twelveWeeksAgo = pinned.subtract(const Duration(days: 7 * 11));
      final dailyRows = await (db.select(
        db.clientDailyMetrics,
      )..where((t) => t.clientId.equals(full.id))).get();
      final oldest = dailyRows
          .map((row) => row.date)
          .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
      expect(
        DateTime.parse(oldest).isBefore(twelveWeeksAgo),
        isTrue,
        reason: '${full.name} 이력이 12주에 못 미친다 ($oldest)',
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
      await db.putValue('trainer_seeded_v18', '2020-01-01');

      await seedIfEmpty(db);

      final schedule = await db.select(db.trainerScheduleEntries).get();
      expect(schedule.every((s) => s.date == _todayString()), isTrue);
      expect(await db.readValue('trainer_seeded_v18'), _todayString());
    });

    test(
      'seed chat messages are in the past so runtime replies sort after',
      () async {
        await seedIfEmpty(db);

        // All seed messages must predate "now" (they use past timestamps),
        // otherwise a reply added right after boot could interleave.
        final now = nowKst();
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
                createdAt: nowKst(),
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
        await db.putValue('trainer_seeded_v12', today);
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

        expect(await db.readValue('trainer_seeded_v18'), today);
      },
    );

    test('목록 미리보기가 그 스레드의 마지막 메시지와 같다', () async {
      // 예전에는 로스터의 `lastMessage` 를 손으로 적어 뒀다. 대화를 손볼 때
      // 한쪽만 바뀌어서, 김민수는 우연히 맞고 박성호는 회원이 보낸 옛
      // 메시지가 목록에 떴다 — 같은 화면이 고객마다 다른 말을 했다.
      await seedIfEmpty(db);

      final clients = await db.select(db.trainerClients).get();
      expect(clients, isNotEmpty);
      for (final client in clients) {
        final thread =
            await (db.select(db.clientChatMessages)
                  ..where((t) => t.clientId.equals(client.id))
                  ..orderBy(<OrderingTerm Function($ClientChatMessagesTable)>[
                    (t) => OrderingTerm(expression: t.createdAt),
                  ]))
                .get();
        expect(
          client.lastMessage,
          thread.isEmpty ? '' : thread.last.body,
          reason: '${client.name}(${client.id})의 미리보기가 스레드와 어긋난다',
        );
      }
    });

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
              createdAt: nowKst(),
            ),
          );

      // Force a re-seed.
      await db.putValue('trainer_seeded_v18', '2020-01-01');
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
