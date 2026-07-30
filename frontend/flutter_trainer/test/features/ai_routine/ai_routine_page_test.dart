import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';

import '../../helpers/pump_app.dart';

/// A chat repository whose sends always fail.
class _FailingChatRepository extends ChatRepository {
  const _FailingChatRepository(super.db);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async => throw Exception('chat write failed');
}

/// A chat repository whose sends resolve slowly, so a client switch can
/// land while a send is still in flight (review PR 239).
class _SlowChatRepository extends ChatRepository {
  const _SlowChatRepository(super.db);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return super.sendTrainerMessage(clientId: clientId, text: text);
  }
}

/// Counts registration calls and delays them, to test the in-flight
/// double-tap guard.
class _SlowCountingRoutineRepository extends AiRoutineRepository {
  _SlowCountingRoutineRepository(super.db);

  int registerCalls = 0;

  @override
  Future<bool> registerToSchedule({
    required String date,
    required String clientName,
    required List<Map<String, Object?>> program,
  }) async {
    registerCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return super.registerToSchedule(
      date: date,
      clientName: clientName,
      program: program,
    );
  }
}

void main() {
  group('AiRoutineRepository.watchRoutine', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns the 3 seeded suggestions in order per client', () async {
      final repo = AiRoutineRepository(db);
      final minsu = await repo.watchRoutine('seed-client-1').first;
      expect(minsu.length, 3);
      expect(minsu.first.name, '저강도 유산소 (걷기)');
      expect(minsu.first.minutes, 30);
      expect(minsu.first.type, '유산소');

      final jisu = await repo.watchRoutine('seed-client-2').first;
      expect(jisu.first.name, '인터벌 런닝');
    });

    test(
      'registerToTodaySchedule attaches to an existing 예정 session',
      () async {
        final repo = AiRoutineRepository(db);
        // 박성호 has a seeded 15:00 예정 session.
        final attached = await repo.registerToSchedule(
          date: ymd(DateTime.now()),
          clientName: '박성호',
          program: <Map<String, Object?>>[
            <String, Object?>{
              'name': '저강도 유산소',
              'sets': 1,
              'reps': '30분',
              'weight': '-',
            },
          ],
        );
        expect(attached, isTrue);

        final rows = await db.select(db.trainerScheduleEntries).get();
        final his = rows.where((r) => r.clientName == '박성호').toList();
        expect(his.length, 1); // no extra slot booked
        expect(his.single.programJson, contains('저강도 유산소'));
      },
    );

    test(
      'registerToTodaySchedule books a new slot when no 예정 exists',
      () async {
        final repo = AiRoutineRepository(db);
        // 김민수's only session today is 완료 — a new slot gets booked.
        final attached = await repo.registerToSchedule(
          date: ymd(DateTime.now()),
          clientName: '김민수',
          program: <Map<String, Object?>>[
            <String, Object?>{
              'name': '코어 강화',
              'sets': 1,
              'reps': '10분',
              'weight': '-',
            },
          ],
        );
        expect(attached, isFalse);

        final rows = await db.select(db.trainerScheduleEntries).get();
        final his = rows.where((r) => r.clientName == '김민수').toList();
        expect(his.length, 2);
        final booked = his.firstWhere((r) => r.status == '예정');
        expect(booked.programJson, contains('코어 강화'));
        expect(booked.id.startsWith('seed-'), isFalse);
      },
    );
  });

  group('AiRoutinePage', () {
    Future<void> openTab(WidgetTester tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      await tester.tap(find.text('AI루틴')); // bottom-nav label
      await settle(tester);
    }

    testWidgets('defaults to the first client with verdict and routine', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('AI 루틴 생성'), findsOneWidget);
      // 김민수 (2100mg, over) → cardio-boost verdict.
      expect(find.text('✦ AI 판단: 나트륨 초과 → 유산소 강화 권장'), findsOneWidget);
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
      expect(find.text('혈압 안정에 효과적'), findsOneWidget);
    });

    testWidgets('switching client updates the verdict and suggestions', (
      tester,
    ) async {
      await openTab(tester);

      await tester.tap(find.text('이지수'));
      await settle(tester);

      // 이지수 (1800mg, under) → balanced verdict + her routine.
      expect(find.text('✦ AI 판단: 식단 균형 양호 → 근력 중심 루틴 유지'), findsOneWidget);
      expect(find.text('인터벌 런닝'), findsOneWidget);
      expect(find.text('저강도 유산소 (걷기)'), findsNothing);
    });

    testWidgets('adding and deleting a custom exercise', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '레그프레스 5세트');
      await tester.ensureVisible(find.text('추가하기'));
      await tester.pump();
      await tester.tap(find.text('추가하기'));
      await tester.pump();
      // The new custom card may land below the fold.
      await tester.scrollUntilVisible(
        find.text('레그프레스 5세트'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('레그프레스 5세트'), findsOneWidget);
      expect(find.text('트레이너 추가'), findsOneWidget);

      // Delete it again.
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pump();
      expect(find.text('레그프레스 5세트'), findsNothing);
    });

    testWidgets('send reset also closes the add-exercise form', (tester) async {
      await openTab(tester);

      // Open the add form, then send with it still open.
      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      expect(find.text('운동 추가'), findsOneWidget);

      // The open form's TextField adds an inner Scrollable — target the
      // page ListView explicitly.
      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 4)); // reset window
      // The add form must be closed again after the reset.
      expect(find.text('운동 추가'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('＋ 운동 직접 추가'), findsOneWidget);
    });

    testWidgets('an AI suggestion can be removed for this round', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
      // Every card carries an X now — the first belongs to the first
      // AI suggestion.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(find.text('저강도 유산소 (걷기)'), findsNothing);

      // Switching clients and back restores the full suggestion list.
      await tester.tap(find.text('이지수'));
      await settle(tester);
      await tester.tap(find.text('김민수'));
      await settle(tester);
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
    });

    testWidgets('오늘 스케줄에 등록 writes the routine onto the schedule tab', (
      tester,
    ) async {
      await openTab(tester);

      // 박성호 → his 15:00 예정 session receives the program.
      await tester.tap(find.text('박성호'));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await settle(tester);

      expect(find.text('오늘 스케줄에 등록됨'), findsOneWidget);
      expect(find.text('스케줄 탭에서 오늘 세션의 프로그램으로 확인할 수 있어요'), findsOneWidget);

      // The 스케줄 tab shows the registered plan on his 예정 session.
      await tester.tap(find.text('스케줄'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('벤치프레스 4세트'), 120);
      expect(find.text('벤치프레스 4세트'), findsOneWidget); // AI routine item
    });

    testWidgets('homework send leaves a trace in the client chat', (
      tester,
    ) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await settle(tester);

      // The 고객 tab's chat thread now shows the homework message.
      await tester.tap(find.text('고객'));
      await settle(tester);
      await tester.tap(find.text('김민수'));
      await settle(tester);
      expect(find.textContaining('📋 AI 루틴 숙제를 보냈어요'), findsOneWidget);
    });

    testWidgets('내일 chip registers the routine on the next day', (
      tester,
    ) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
      );
      await tester.tap(find.text('AI루틴'));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text('내일'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('내일'));
      await tester.pump();
      await tester.tap(find.text('내일'));
      await tester.pump();

      await tester.tap(find.textContaining('내일 PT 스케줄에 등록'));
      await settle(tester);
      expect(find.text('내일 스케줄에 등록됨'), findsOneWidget);

      // Booked under tomorrow's date, not today's. Reading a drift stream
      // must run outside the fake-async zone (`runAsync`), otherwise the
      // subscription never flushes and the test hangs.
      final tomorrow = ymd(DateTime.now().add(const Duration(days: 1)));
      final rows = await tester.runAsync(
        () => container
            .read(scheduleRepositoryProvider)
            .watchDate(tomorrow)
            .first,
      );
      expect(rows!.single.clientName, '김민수');
      expect(rows.single.program, isNotEmpty);

      // Drain the 3s confirmation timer so it isn't left pending.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('send shows confirmation then resets edits', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump();

      expect(find.text('✓ 김민수님에게 전송 완료!'), findsOneWidget);
      expect(find.text('고객 앱에 알림이 전송됐어요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4)); // reset window
      expect(find.textContaining('검토 완료'), findsOneWidget);
    });

    testWidgets('mashing 스케줄 등록 registers only once', (tester) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          // Shares the app's seeded DB so the AI suggestions load.
          aiRoutineRepositoryProvider.overrideWith(
            (ref) =>
                _SlowCountingRoutineRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await tester.tap(find.text('AI루틴'));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump(const Duration(milliseconds: 50));
      // Second tap lands mid-flight — the button is now disabled and its
      // label has flipped, so this must NOT trigger a second register.
      await tester.tap(
        find.textContaining('스케줄에 등록').first,
        warnIfMissed: false,
      );
      await settle(tester);

      final repo =
          container.read(aiRoutineRepositoryProvider)
              as _SlowCountingRoutineRepository;
      expect(repo.registerCalls, 1);
    });

    testWidgets('switching clients mid-registration does not flash success '
        'on the new client', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          aiRoutineRepositoryProvider.overrideWith(
            (ref) =>
                _SlowCountingRoutineRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await tester.tap(find.text('AI루틴'));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump(const Duration(milliseconds: 50));

      // Switch client while the write for 김민수 is still in flight —
      // the picker is above the button, so scroll back up to it.
      await tester.scrollUntilVisible(
        find.text('이지수'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('이지수'));
      await tester.pump();
      await tester.tap(find.text('이지수'));
      await settle(tester);

      // 이지수's card must not claim the registration, and her button
      // must not be left disabled by the previous client's guard.
      expect(find.text('오늘 스케줄에 등록됨'), findsNothing);
      expect(find.text('오늘 PT 스케줄에 등록'), findsOneWidget);
    });

    testWidgets('a failed chat write does not show the send confirmation', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          chatRepositoryProvider.overrideWith(
            (ref) => _FailingChatRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await tester.tap(find.text('AI루틴'));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await settle(tester);

      // The homework write failed — no success flash, and the button is
      // still actionable (review PR 239).
      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
      expect(find.text('✓ 김민수님에게 전송 완료!'), findsNothing);
      expect(find.textContaining('검토 완료'), findsOneWidget);
    });

    testWidgets('A → B → A cannot double-register while A is still saving', (
      tester,
    ) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          aiRoutineRepositoryProvider.overrideWith(
            (ref) =>
                _SlowCountingRoutineRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await tester.tap(find.text('AI루틴'));
      await settle(tester);

      // Matches both the idle '📅 …등록' and the in-flight/disabled
      // '✓ …등록됨' label so it works before and during a save.
      Future<void> tapRegister() async {
        final f = find.textContaining('스케줄에 등록');
        await tester.scrollUntilVisible(
          f,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(f);
        await tester.pump();
        await tester.tap(f, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }

      Future<void> selectClient(String name) async {
        await tester.scrollUntilVisible(
          find.text(name),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(name));
        await tester.pump();
        await tester.tap(find.text(name));
        await tester.pump(const Duration(milliseconds: 30));
      }

      // Start 김민수's (slow) registration, hop to 이지수 and back.
      await tapRegister();
      await selectClient('이지수');
      await selectClient('김민수');
      // Back on 김민수 while the first write is still in flight — the
      // button stays disabled, so this tap must NOT start a second one.
      await tapRegister();
      await settle(tester);

      final repo =
          container.read(aiRoutineRepositoryProvider)
              as _SlowCountingRoutineRepository;
      expect(repo.registerCalls, 1);
    });

    testWidgets('switching clients mid-send does not flash send success '
        'on the new client and keeps their edits', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          chatRepositoryProvider.overrideWith(
            (ref) => _SlowChatRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await tester.tap(find.text('AI루틴'));
      await settle(tester);

      // Start 김민수's (slow) send, then switch to 이지수 mid-flight.
      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.scrollUntilVisible(
        find.text('이지수'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('이지수'));
      await tester.pump();
      await tester.tap(find.text('이지수'));
      await tester.pump(const Duration(milliseconds: 30));

      // Make a fresh edit on 이지수 while 김민수's send is still in flight.
      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '레그프레스 5세트');
      await tester.ensureVisible(find.text('추가하기'));
      await tester.pump();
      await tester.tap(find.text('추가하기'));
      await tester.pump();
      await settle(tester); // let 김민수's send + reset window elapse

      // 김민수's send resolved while 이지수 is on screen: no success flash
      // lands on 이지수, and her edit survives — 김민수's reset timer must
      // not fire against her (review PR 239).
      expect(find.text('✓ 김민수님에게 전송 완료!'), findsNothing);
      expect(find.text('✓ 이지수님에게 전송 완료!'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('레그프레스 5세트'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('레그프레스 5세트'), findsOneWidget);
    });

    testWidgets('registering with every exercise removed shows a hint', (
      tester,
    ) async {
      await openTab(tester);

      // Remove all three seeded AI suggestions for 김민수.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pump();
      }

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();

      expect(find.text('운동을 하나 이상 추가해 주세요'), findsOneWidget);
    });
  });
}
