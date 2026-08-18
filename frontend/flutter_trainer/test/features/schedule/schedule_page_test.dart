import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';

import '../../helpers/pump_app.dart';

/// A chat repository whose sends always fail.
class _FailingChatRepository extends DriftChatRepository {
  const _FailingChatRepository(super.db);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async => throw Exception('chat write failed');
}

/// A repository whose writes always fail — to exercise error handling.
class _ThrowingScheduleRepository extends DriftScheduleRepository {
  const _ThrowingScheduleRepository(super.db);

  @override
  Future<void> addSession({
    required String date,
    required String clientName,
    String? clientId,
    required String time,
    required String type,
    required int durationMinutes,
    String note = '',
  }) async => throw Exception('add failed');

  @override
  Future<void> deleteSession(String id) async => throw Exception('del failed');

  @override
  Future<void> completeSession(String id, {String note = ''}) async =>
      throw Exception('complete failed');
}

void main() {
  group('ScheduleRepository.watchToday', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns the 6 seeded slots in timeline order', () async {
      final slots = await DriftScheduleRepository(db).watchToday().first;
      expect(slots.length, 6);
      expect(slots.map((s) => s.time).toList(), <String>[
        '10:00',
        '12:00',
        '14:00',
        '15:00',
        '17:00',
        '19:00',
      ]);
      expect(slots.where((s) => s.isGap).length, 2);
    });

    // #386 회귀: 스케줄이 고객을 이름으로 참조하던 시절에는 고객 이름을
    // 바꾸면 과거 세션이 통째로 끊겼다. 크래시도 오류 표시도 없이 주간
    // 리포트가 "세션 0건" 이 되고, 그대로 회원에게 전송될 수 있었다.
    test('고객 이름을 바꿔도 과거 세션이 끊기지 않는다', () async {
      final repo = DriftScheduleRepository(db);
      const key = (id: 'seed-client-1', name: '김민수');
      final before = await repo.watchClientSessions(key).first;
      expect(before, isNotEmpty, reason: '시드에 김민수 세션이 있어야 한다');

      await (db.update(db.trainerClients)
            ..where((t) => t.id.equals('seed-client-1')))
          .write(const TrainerClientsCompanion(name: Value('김민수2')));

      final after = await repo.watchClientSessions((
        id: 'seed-client-1',
        name: '김민수2',
      )).first;
      expect(after.length, before.length);
    });

    test('이름이 같아도 다른 고객의 세션은 섞이지 않는다', () async {
      final repo = DriftScheduleRepository(db);
      // 이름만 같고 id 가 다른 고객은 남의 세션을 가져오면 안 된다.
      final sessions = await repo.watchClientSessions((
        id: 'other-client',
        name: '김민수',
      )).first;
      expect(sessions, isEmpty);
    });

    test('v3 이전 행(client_id 없음)은 이름으로 폴백한다', () async {
      // 마이그레이션만 거친 기존 설치를 흉내 낸다 — client_id 가 null 이다.
      await db
          .into(db.trainerScheduleEntries)
          .insert(
            TrainerScheduleEntriesCompanion.insert(
              id: 'legacy-row',
              date: ymd(nowKst()),
              time: '21:00',
              status: '예정',
              clientName: const Value('  김민수  '), // 공백까지 섞인 기존 데이터
            ),
          );

      final sessions = await DriftScheduleRepository(
        db,
      ).watchClientSessions((id: 'seed-client-1', name: '김민수')).first;
      expect(sessions.any((s) => s.id == 'legacy-row'), isTrue);
    });

    test('decodes the PT program and expandability rules', () async {
      final slots = await DriftScheduleRepository(db).watchToday().first;
      final minsu = slots.firstWhere((s) => s.clientName == '김민수');
      expect(minsu.expandable, isTrue); // 완료 + program
      expect(minsu.program.length, 4);
      expect(minsu.program.first.name, '레그프레스');
      expect(minsu.program.first.sets, 3);
      expect(minsu.program.first.weight, '80kg');

      final seongho = slots.firstWhere((s) => s.clientName == '박성호');
      expect(seongho.expandable, isTrue); // 예정 now opens (plan preview)
      expect(seongho.isUpcoming, isTrue);
      final consult = slots.firstWhere((s) => s.clientName == '신규 고객');
      expect(consult.program, isEmpty);
      expect(consult.expandable, isTrue); // opens with the no-plan hint
    });

    test('addSession inserts an 예정 slot sorted into the timeline', () async {
      final repo = DriftScheduleRepository(db);
      await repo.addSession(
        date: ymd(nowKst()),
        clientName: '이지수',
        time: '10:15',
        type: '1:1 PT',
        durationMinutes: 45,
      );
      final slots = await repo.watchToday().first;
      expect(slots.length, 7);
      // Lands right after the 10:00 session (time-ordered).
      expect(slots[1].time, '10:15');
      expect(slots[1].clientName, '이지수');
      expect(slots[1].isUpcoming, isTrue);
      expect(slots[1].id.startsWith('seed-'), isFalse);
    });

    test('updateSession moves a slot to a 15-minute step', () async {
      final repo = DriftScheduleRepository(db);
      final before = await repo.watchToday().first;
      final target = before.firstWhere((s) => s.clientName == '박성호');
      await repo.updateSession(
        target.id,
        clientName: target.clientName,
        time: '19:30',
        type: target.type,
        durationMinutes: 90,
        note: target.note,
      );
      final after = await repo.watchToday().first;
      final moved = after.firstWhere((s) => s.clientName == '박성호');
      expect(moved.time, '19:30');
      expect(moved.durationMinutes, 90);
    });

    test(
      'updateProgram changes exercises without changing the booking',
      () async {
        final repo = DriftScheduleRepository(db);
        final before = await repo.watchToday().first;
        final target = before.firstWhere((s) => s.clientName == '박성호');

        await repo.updateProgram(
          target.id,
          program: const <ProgramItem>[
            ProgramItem(name: '덤벨 프레스', sets: 4, reps: '12회', weight: '16kg'),
          ],
          note: '마지막 세트 RPE 8 확인',
        );

        final after = await repo.watchToday().first;
        final updated = after.firstWhere((s) => s.id == target.id);
        expect(updated.time, target.time);
        expect(updated.clientName, target.clientName);
        expect(updated.program.single.name, '덤벨 프레스');
        expect(updated.program.single.sets, 4);
        expect(updated.note, '마지막 세트 RPE 8 확인');
      },
    );

    test('completeSession flips 예정 to 완료 and logs the 운동기록', () async {
      final repo = DriftScheduleRepository(db);
      final before = await repo.watchToday().first;
      final target = before.firstWhere((s) => s.clientName == '박성호');
      expect(target.isUpcoming, isTrue);

      await repo.completeSession(target.id, note: '벤치 폼 안정적');

      final after = await repo.watchToday().first;
      final done = after.firstWhere((s) => s.clientName == '박성호');
      expect(done.isDone, isTrue);
      expect(done.note, '벤치 폼 안정적');

      // Logged newest-first into his history.
      final history = await db.select(db.clientRoutineHistory).get()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final logged = history.firstWhere((h) => h.id.startsWith('hist-'));
      expect(logged.clientId, 'seed-client-3');
      expect(logged.label, 'PT 세션 · 트레이너 지도');
      expect(logged.trainerNote, '벤치 폼 안정적');
      expect(logged.exercisesJson, contains('벤치프레스'));
      expect(logged.sortOrder, lessThan(0)); // sorts before seed rows
    });

    test('concurrent completeSession calls log the 운동기록 once', () async {
      final repo = DriftScheduleRepository(db);
      final before = await repo.watchToday().first;
      final target = before.firstWhere((s) => s.clientName == '박성호');

      // Both calls observe 예정 before either commits — only the one that
      // actually flips the status may write history (review PR 237).
      await Future.wait<void>(<Future<void>>[
        repo.completeSession(target.id, note: '첫 번째'),
        repo.completeSession(target.id, note: '두 번째'),
      ]);

      final history = await db.select(db.clientRoutineHistory).get();
      final logged = history.where((h) => h.id.startsWith('hist-')).toList();
      expect(logged.length, 1, reason: '완료 처리는 멱등해야 함');

      // A later completion of an already-완료 session is also a no-op.
      await repo.completeSession(target.id, note: '세 번째');
      final after = await db.select(db.clientRoutineHistory).get();
      expect(after.where((h) => h.id.startsWith('hist-')).length, 1);
    });

    test(
      'completeSession with an empty memo keeps the existing note',
      () async {
        final repo = DriftScheduleRepository(db);
        // A booked 예정 session that already carries a note.
        await db
            .into(db.trainerScheduleEntries)
            .insert(
              TrainerScheduleEntriesCompanion.insert(
                id: 'sched-noted',
                date: ymd(nowKst()),
                time: '18:00',
                clientName: const Value('이지수'),
                type: const Value('1:1 PT'),
                durationMinutes: const Value(60),
                status: '예정',
                note: const Value('허리 통증 주의'),
                programJson: const Value('[]'),
              ),
            );

        await repo.completeSession('sched-noted'); // no memo entered

        final after = await repo.watchToday().first;
        final done = after.firstWhere((s) => s.id == 'sched-noted');
        expect(done.isDone, isTrue);
        expect(done.note, '허리 통증 주의'); // preserved, not wiped
      },
    );

    test(
      'completeSession without a known client only flips the status',
      () async {
        final repo = DriftScheduleRepository(db);
        final before = await repo.watchToday().first;
        final consult = before.firstWhere((s) => s.clientName == '신규 고객');
        final histBefore =
            (await db.select(db.clientRoutineHistory).get()).length;

        await repo.completeSession(consult.id);

        final after = await repo.watchToday().first;
        expect(after.firstWhere((s) => s.clientName == '신규 고객').isDone, isTrue);
        final histAfter =
            (await db.select(db.clientRoutineHistory).get()).length;
        expect(histAfter, histBefore); // no orphan history row
      },
    );

    test('watchDate separates timelines per calendar day', () async {
      final repo = DriftScheduleRepository(db);
      final tomorrow = ymd(nowKst().add(const Duration(days: 1)));

      expect(await repo.watchDate(tomorrow).first, isEmpty);

      await repo.addSession(
        date: tomorrow,
        clientName: '이지수',
        time: '11:00',
        type: '1:1 PT',
        durationMinutes: 60,
      );

      final tomorrowSlots = await repo.watchDate(tomorrow).first;
      expect(tomorrowSlots.single.clientName, '이지수');
      // Today's timeline is untouched.
      expect((await repo.watchToday().first).length, 6);
      // …and the booked-dates set now covers both days.
      final booked = await repo.watchBookedDates().first;
      expect(booked, containsAll(<String>[ymd(nowKst()), tomorrow]));
    });

    test('completing a non-today session labels its own date', () async {
      final repo = DriftScheduleRepository(db);
      // A PAST session — completing it retro-logs the class. Future
      // sessions can't be completed (see the next test).
      final yesterday = nowKst().subtract(const Duration(days: 1));
      await repo.addSession(
        date: ymd(yesterday),
        clientName: '이지수',
        time: '11:00',
        type: '1:1 PT',
        durationMinutes: 60,
      );
      final slot = (await repo.watchDate(ymd(yesterday)).first).single;

      await repo.completeSession(slot.id, note: '어제 세션 뒤늦게 기록');

      final history = await db.select(db.clientRoutineHistory).get();
      final logged = history.firstWhere((h) => h.id.startsWith('hist-'));
      expect(logged.dateLabel, '${yesterday.month}/${yesterday.day}');
      expect(logged.dateLabel.contains('(오늘)'), isFalse);
    });

    test('completeSession refuses a future-dated session', () async {
      final repo = DriftScheduleRepository(db);
      final tomorrow = nowKst().add(const Duration(days: 1));
      await repo.addSession(
        date: ymd(tomorrow),
        clientName: '이지수',
        time: '11:00',
        type: '1:1 PT',
        durationMinutes: 60,
      );
      final slot = (await repo.watchDate(ymd(tomorrow)).first).single;

      // You can't complete a class that hasn't happened yet — the call is
      // a no-op, the session stays 예정 and nothing is logged (review 245).
      await repo.completeSession(slot.id, note: '미리 완료 시도');

      final after = (await repo.watchDate(ymd(tomorrow)).first).single;
      expect(after.status, '예정');
      final history = await db.select(db.clientRoutineHistory).get();
      expect(history.where((h) => h.id.startsWith('hist-')), isEmpty);
    });

    test('client sessions match on the same normalisation as the uniqueness '
        'guard (trim + lowercase)', () async {
      // addClient blocks duplicates on lower(trim(name)) but addSession
      // stores the trainer's raw input. An exact compare here returned
      // nothing for a name saved with stray whitespace, and the weekly
      // report then showed 0 sessions with no error (CodeRabbit #377).
      final repo = DriftScheduleRepository(db);
      await repo.addSession(
        date: ymd(nowKst()),
        clientName: '  김민수  ',
        time: '21:00',
        type: '1:1 PT',
        durationMinutes: 60,
      );

      final found = await repo.watchClientSessions((
        id: 'seed-client-1',
        name: '김민수',
      )).first;
      expect(found.any((s) => s.time == '21:00'), isTrue);
    });

    test('deleteSession removes the slot', () async {
      final repo = DriftScheduleRepository(db);
      final before = await repo.watchToday().first;
      final target = before.firstWhere((s) => s.clientName == '신규 고객');
      await repo.deleteSession(target.id);
      final after = await repo.watchToday().first;
      expect(after.length, before.length - 1);
      expect(after.where((s) => s.clientName == '신규 고객'), isEmpty);
    });
  });

  group('SchedulePage', () {
    Future<void> openSchedule(WidgetTester tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.schedule,
      );
    }

    testWidgets('renders header, week strip, and the timeline', (tester) async {
      await openSchedule(tester);

      expect(find.text('스케줄'), findsWidgets);
      expect(find.text('김민수'), findsOneWidget);
      expect(find.text('이지수'), findsOneWidget);
      expect(find.text('1:1 PT · 60분'), findsWidgets);
      // Two of the day's sessions are already 완료 — the status word on
      // the row, not the action chip.
      expect(find.text('완료'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.text('신규 고객'), 120);
      expect(find.text('박성호'), findsOneWidget);
      expect(find.text('상담 · 30분'), findsOneWidget);
      // Lazy list: off-screen rows are disposed, so assert presence
      // rather than an exact count.
      expect(find.text('빈 시간'), findsWidgets);
      expect(find.text('예정'), findsWidgets);
    });

    testWidgets('week detail follows the URL date after selecting a session', (
      tester,
    ) async {
      final today = nowKst();
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.scheduleView('week', date: ymd(today)),
      );

      await tester.tap(find.text('김민수').first);
      await settle(tester);
      await goTo(
        tester,
        AppRoutes.scheduleView(
          'week',
          date: ymd(today.add(const Duration(days: 1))),
        ),
      );

      // The old selected card still appears once in the week's grid, but it
      // must not be duplicated in the detail panel for tomorrow.
      expect(find.text('김민수'), findsOneWidget);
    });

    // 진입점은 카드형 버튼이다 — 대기 건이 있을 때만 강조되고, 건수를
    // 아이콘 배지가 아니라 문구로 말한다(#858).
    testWidgets('상담 요청 진입점은 대기 건수를 문구로 보여 준다', (tester) async {
      await openSchedule(tester);

      final Finder entry = find.byKey(const Key('consult-inbox-entry'));
      expect(entry, findsOneWidget);
      // 시드에 대기 1건 — '대기 중 1건' 이 그 자리에서 읽혀야 한다.
      expect(find.text('대기 중 1건'), findsOneWidget);
      expect(find.text('대기 중인 요청이 없어요'), findsNothing);
    });

    testWidgets('대기 건이 없으면 강조 대신 없음을 말한다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.schedule,
        extraOverrides: <Override>[
          consultationRepositoryProvider.overrideWithValue(
            DemoConsultationRepository(requests: <ConsultationRequest>[]),
          ),
        ],
      );

      expect(find.byKey(const Key('consult-inbox-entry')), findsOneWidget);
      expect(find.text('대기 중인 요청이 없어요'), findsOneWidget);
      expect(find.text('대기 중 0건'), findsNothing);
    });

    testWidgets('상담 요청 진입점이 좁은 폭에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSchedule(tester);

      expect(find.byKey(const Key('consult-inbox-entry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('consultation inbox opens from the schedule tab', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.tap(find.byKey(const Key('consult-inbox-entry')));
      await settle(tester);

      expect(find.text('김하늘'), findsOneWidget);
      expect(find.text('퇴근 후 가능한 시간으로 첫 상담을 받고 싶어요.'), findsOneWidget);
      expect(find.text('거절'), findsOneWidget);
      expect(find.text('새 일정'), findsWidgets);
    });

    testWidgets(
      'failed demo schedule write keeps the consultation pending for retry',
      (tester) async {
        final container = await pumpTrainerApp(
          tester,
          token: 'demo-trainer-token',
          at: AppRoutes.schedule,
          extraOverrides: <Override>[
            scheduleRepositoryProvider.overrideWith(
              (ref) =>
                  _ThrowingScheduleRepository(ref.watch(appDatabaseProvider)),
            ),
          ],
        );
        final consultations = container.read(consultationRepositoryProvider);

        await tester.tap(find.text('상담 요청'));
        await settle(tester);
        await tester.tap(find.text('새 일정').last);
        await settle(tester);
        await tester.tap(find.text('추가하기'));
        await settle(tester);

        expect(await consultations.pendingCount(), 1);
        expect((await consultations.fetch()).single.isPending, isTrue);
        expect(find.text('상담을 처리하지 못했어요'), findsOneWidget);
      },
    );

    testWidgets('past preferred date opens a valid consultation date picker', (
      tester,
    ) async {
      final consultations = DemoConsultationRepository(
        requests: <ConsultationRequest>[
          ConsultationRequest(
            id: 'past-consultation',
            memberId: 'past-member',
            memberName: '과거희망일 회원',
            goalCode: 'fitness',
            purposeCode: 'general',
            preferredDate: DateTime(2020),
            preferredTimeCode: 'morning',
            status: 'pending',
          ),
        ],
      );
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.schedule,
        extraOverrides: <Override>[
          consultationRepositoryProvider.overrideWithValue(consultations),
        ],
      );

      await tester.tap(find.text('상담 요청'));
      await settle(tester);
      await tester.tap(find.text('새 일정').last);
      await settle(tester);
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('blank consultation rejection reason cannot be submitted', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.tap(find.text('상담 요청'));
      await settle(tester);
      await tester.tap(find.text('거절'));
      await settle(tester);

      TextButton rejectButton() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, '반려하기'));
      expect(rejectButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, '   ');
      await tester.pump();
      expect(rejectButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, '요청 시간 조율 필요');
      await tester.pump();
      expect(rejectButton().onPressed, isNotNull);
    });

    testWidgets('예약 슬롯 action opens the selected-day management sheet', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.tap(find.text('예약 슬롯'));
      await settle(tester);

      expect(find.text('예약 슬롯 관리'), findsOneWidget);
      expect(find.textContaining('고객이 예약할 시간을 엽니다'), findsOneWidget);
      expect(find.text('열기'), findsOneWidget);
    });

    testWidgets('완료 세션의 프로그램을 회원에게 보내고 그 사실이 남는다 (#822)', (tester) async {
      // 펼친 완료 카드와 그 아래 전송 버튼이 한 화면에 들어와야 탭이 닿는다.
      await withWideSurface(tester, () async {
        await openSchedule(tester);

        // Expand 김민수 (완료).
        await tester.tap(find.text('김민수'));
        await tester.pump();
        expect(find.text('레그프레스'), findsOneWidget);
        expect(find.text('카프레이즈'), findsOneWidget);
        expect(find.text('트레이너 메모'), findsOneWidget);
        expect(find.text('무릎 컨디션 양호. 레그프레스 중량 소폭 증가 가능.'), findsOneWidget);

        // 예전에는 이 자리가 눌리지 않는 안내였다("전송 API가 아직 없어…").
        expect(find.text('김민수님에게 전송됨'), findsNothing);
        final send = find.byKey(
          const ValueKey<String>('schedule-send-program'),
        );
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        await tester.tap(send);
        await tester.pumpAndSettle();

        // 보낸 뒤에는 같은 자리가 그 사실을 말하고, 다시 누를 수 없다.
        expect(find.text('김민수님에게 전송됨'), findsWidgets);
        final button = tester.widget<InkWell>(
          find
              .ancestor(
                of: find.text('김민수님에게 전송됨').first,
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(button.onTap, isNull);
      }, size: const Size(1100, 2000));
    });

    testWidgets('예정 session expands to the plan preview with manage '
        'actions', (tester) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('일정 수정'), 120);
      expect(find.text('벤치프레스'), findsOneWidget); // planned program
      expect(find.text('일정 수정'), findsOneWidget);
      expect(find.text('프로그램 수정'), findsOneWidget);
      expect(find.text('삭제'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('session-chat-chip')),
        findsOneWidget,
      );
    });

    testWidgets('예정 session without a plan shows the no-plan hint', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('신규 고객'), 120);
      await tester.ensureVisible(find.text('신규 고객'));
      await tester.pump();
      await tester.tap(find.text('신규 고객'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('아직 계획된 프로그램이 없어요'), 120);
      expect(find.text('아직 계획된 프로그램이 없어요'), findsOneWidget);
    });

    testWidgets('새 일정 추가 books a session at a 15-minute step', (tester) async {
      await openSchedule(tester);

      await tester.tap(find.text('새 일정'));
      await settle(tester);

      // Change 00분 → 15분 in the time picker.
      await tester.tap(find.text('00분'));
      await settle(tester);
      await tester.tap(find.text('15분').last);
      await settle(tester);

      await tester.tap(find.text('추가하기'));
      await settle(tester);

      expect(find.text('10:15'), findsOneWidget);
    });

    testWidgets('일정 수정 moves 박성호 to a 15-minute step (15:00 → 15:30)', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('일정 수정'), 120);
      await tester.ensureVisible(find.text('일정 수정'));
      await tester.pump();
      await tester.tap(find.text('일정 수정'));
      await settle(tester);

      // Booking details stay inside the expanded schedule card. Program and
      // trainer memo editing have their own separate action.
      expect(
        find.byKey(
          const ValueKey<String>('inline-session-editor-seed-schedule-3'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('schedule-trainer-note')),
        findsNothing,
      );

      // Change 00분 → 30분 in the time picker and save.
      await tester.tap(find.text('00분'));
      await settle(tester);
      await tester.tap(find.text('30분').last);
      await settle(tester);
      await tester.ensureVisible(find.text('저장하기'));
      await tester.pump();
      await tester.tap(find.text('저장하기'));
      await settle(tester);

      expect(find.text('15:30'), findsOneWidget);
      expect(find.text('15:00'), findsNothing);
    });

    testWidgets('프로그램 수정 edits exercises and memo inside the card', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('프로그램 수정'), 120);
      await tester.ensureVisible(find.text('프로그램 수정'));
      await tester.pump();
      await tester.tap(find.text('프로그램 수정'));
      await settle(tester);

      expect(
        find.byKey(
          const ValueKey<String>('inline-program-editor-seed-schedule-3'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('inline-session-editor-seed-schedule-3'),
        ),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('program-name-0')),
        '덤벨 플라이',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('program-sets-0')),
        '4',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('program-trainer-note')),
        '견갑 고정 확인',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('save-program')),
      );
      await tester.pump();
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('save-program')),
      );
      save.onPressed!();
      await settle(tester);

      expect(
        find.byKey(
          const ValueKey<String>('inline-program-editor-seed-schedule-3'),
        ),
        findsNothing,
      );
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('덤벨 플라이'), findsOneWidget);
      expect(find.textContaining('4세트 × 8회'), findsOneWidget);
      expect(find.text('견갑 고정 확인'), findsOneWidget);
    });

    testWidgets('삭제 removes the session after confirmation', (tester) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('신규 고객'), 120);
      await tester.ensureVisible(find.text('신규 고객'));
      await tester.pump();
      await tester.tap(find.text('신규 고객'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('삭제'), 120);
      await tester.ensureVisible(find.text('삭제'));
      await tester.pump();
      await tester.tap(find.text('삭제'));
      await settle(tester);
      // Confirm in the dialog (its action is the last 삭제 on screen).
      await tester.tap(find.text('삭제').last);
      await settle(tester);

      expect(find.text('신규 고객'), findsNothing);
    });

    testWidgets('unsupported program send does not create a chat bubble', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.tap(find.text('김민수'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('오늘 PT 프로그램 전송'),
        150,
      );
      // There is no delivery endpoint, so merely rendering the disabled
      // action must not manufacture a trainer-authored chat event.
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-1', section: 'chat'),
      );
      expect(find.textContaining('📤 오늘 PT 프로그램을 보냈어요'), findsNothing);
    });

    testWidgets('완료 chip marks the session done and shows in 운동기록', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('session-complete-chip')),
        120,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('session-complete-chip')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('session-complete-chip')),
      );
      await settle(tester);

      await tester.enterText(find.byType(TextField).last, '벤치 폼 안정적');
      await tester.tap(find.text('완료 처리'));
      await settle(tester);

      // The card flipped to 완료 (the 완료 action chip is gone).
      expect(
        find.byKey(const ValueKey<String>('session-complete-chip')),
        findsNothing,
      );

      // …and the 운동 sub-tab shows the fresh PT entry. The routines the
      // tab absorbed sit above the history, so scroll down to it.
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-3', section: 'workout'),
      );
      final workoutScroll = find
          .descendant(
            of: find
                .descendant(
                  of: find.byKey(
                    const ValueKey<String>('workout-seed-client-3'),
                  ),
                  matching: find.byType(ListView),
                )
                .first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('벤치 폼 안정적'),
        150,
        scrollable: workoutScroll,
      );
      expect(find.text('벤치 폼 안정적'), findsOneWidget);
      expect(find.textContaining('(오늘)'), findsWidgets);
    });

    testWidgets('a future session offers no 완료 action', (tester) async {
      await openSchedule(tester);

      // Browse to tomorrow and book a session there.
      final tomorrow = nowKst().add(const Duration(days: 1));
      await tester.tap(find.text('${tomorrow.day}').first);
      await settle(tester);
      await tester.tap(find.text('새 일정'));
      await settle(tester);
      await tester.tap(find.text('추가하기'));
      await settle(tester);

      // Expand the freshly booked 예정 card.
      await tester.tap(find.text('김민수'));
      await tester.pump();

      // Manage actions are there, but 완료 is not — the class is in the
      // future (review PR 245).
      expect(find.text('일정 수정'), findsOneWidget);
      expect(find.text('프로그램 수정'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('session-chat-chip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('session-complete-chip')),
        findsNothing,
      );
    });

    testWidgets('picking another day browses it; 오늘로 returns to today', (
      tester,
    ) async {
      await openSchedule(tester);
      expect(find.text('김민수'), findsOneWidget);
      // On today, the 오늘로 shortcut is hidden.
      expect(find.text('오늘'), findsNothing);

      // Default window is centred on today (D-3…D+3); tap tomorrow.
      final tomorrow = nowKst().add(const Duration(days: 1));
      await tester.tap(find.text('${tomorrow.day}').first);
      await settle(tester);

      // Tomorrow has no seeded sessions → empty state, and 오늘로 appears.
      expect(find.text('김민수'), findsNothing);
      expect(find.textContaining('이 날짜에는 일정이 없어요'), findsOneWidget);
      expect(find.text('오늘'), findsOneWidget);

      // Book a session on the browsed day; the empty state clears.
      await tester.tap(find.text('새 일정'));
      await settle(tester);
      await tester.tap(find.text('추가하기'));
      await settle(tester);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.textContaining('이 날짜에는 일정이 없어요'), findsNothing);

      // 오늘로 → today's seeded timeline is intact and the button hides.
      await tester.tap(find.text('오늘'));
      await settle(tester);
      expect(find.text('김민수'), findsOneWidget);
      expect(find.text('오늘'), findsNothing);
    });

    // 일↔주를 오가도 날짜 정보가 같은 자리에서 시작해야 한다(#859).
    testWidgets('일 보기 날짜 헤더가 주 보기와 같은 왼쪽 자리에 놓인다', (tester) async {
      // 화면이 nowKst() 로 창을 잡으므로 기준 날짜도 KST 여야 한다. 기기가
      // UTC 면 DateTime.now() 와 KST 의 날짜가 갈려 라벨이 어긋난다(#850).
      final today = todayKst();
      final anchor = today.subtract(const Duration(days: 3));
      final end = anchor.add(const Duration(days: 6));
      // 두 보기가 같은 창(window)을 가리키므로 라벨 문구도 같다.
      final label =
          '${anchor.month}월 ${anchor.day}일 – ${end.month}월 ${end.day}일';

      await openSchedule(tester);
      expect(find.text(label), findsOneWidget);
      final dayLeft = tester.getTopLeft(find.text(label)).dx;

      await goTo(tester, AppRoutes.scheduleView('week', date: ymd(today)));
      expect(find.text(label), findsOneWidget);
      final weekLeft = tester.getTopLeft(find.text(label)).dx;

      expect(dayLeft, weekLeft);
    });

    testWidgets('일 보기 스트립은 화면 폭 전체로 퍼지지 않는다', (tester) async {
      // 1440px 콘솔에서 요일 7칸이 균등 분산되면 칸 간격이 200px씩 벌어져
      // 한 주가 한 덩어리로 읽히지 않는다.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSchedule(tester);

      // schedule-day-* 키도 nowKst() 로 만들어진다 — 같은 기준을 쓴다.
      final anchor = todayKst().subtract(const Duration(days: 3));
      final first = find.byKey(ValueKey<String>('schedule-day-${ymd(anchor)}'));
      final last = find.byKey(
        ValueKey<String>(
          'schedule-day-${ymd(anchor.add(const Duration(days: 6)))}',
        ),
      );

      final spanned =
          tester.getBottomRight(last).dx - tester.getTopLeft(first).dx;
      expect(spanned, lessThanOrEqualTo(AppLayout.calendarStripMaxWidth));
    });

    testWidgets('the week strip fits a narrow column without overflowing', (
      tester,
    ) async {
      // A narrow viewport is where the fixed-width cells used to overflow
      // by ~4px; flexible cells must fit any width.
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSchedule(tester);

      // The chevrons render and no RenderFlex overflow was thrown.
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the chevron scrubs the visible week without moving the '
        'selection', (tester) async {
      await openSchedule(tester);
      expect(find.text('김민수'), findsOneWidget); // today selected

      // Shifting the window a week forward keeps today selected, so the
      // timeline still shows today's sessions.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await settle(tester);
      expect(find.text('김민수'), findsOneWidget);
      // Today is now off the visible window, so 오늘로 is offered.
      expect(find.text('오늘'), findsOneWidget);
    });

    testWidgets('채팅 chip jumps to the standalone message thread', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('session-chat-chip')),
        120,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('session-chat-chip')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('session-chat-chip')));
      await settle(tester);

      // Client detail opened on the chat section — the header's message
      // button reads as selected, standing in for the tab it replaced.
      expect(
        find.byKey(const ValueKey<String>('messages-thread-seed-client-3')),
        findsOneWidget,
      );
      // The thread auto-scrolls to the newest message; drag back up so
      // the lazily-built banner at the top of the thread exists.
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pump();
      expect(find.textContaining('AI가 박성호님의'), findsOneWidget);
    });

    testWidgets('editing a session whose client is not in the roster keeps '
        'its own values on a no-op save', (tester) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
      );
      await goTo(tester, AppRoutes.schedule);

      // 신규 고객 (상담, 30분) is booked but is NOT a registered client.
      await tester.scrollUntilVisible(find.text('신규 고객'), 120);
      await tester.ensureVisible(find.text('신규 고객'));
      await tester.pump();
      await tester.tap(find.text('신규 고객'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('일정 수정'), 120);
      await tester.ensureVisible(find.text('일정 수정'));
      await tester.pump();
      await tester.tap(find.text('일정 수정'));
      await settle(tester);

      // Save without changing anything — the sheet must have prefilled
      // the session's own values, not snapped to defaults.
      await tester.ensureVisible(find.text('저장하기'));
      await tester.pump();
      await tester.tap(find.text('저장하기'));
      await settle(tester);

      // Read the row outside fake-async — a drift stream's .first would
      // otherwise deadlock inside testWidgets.
      String? clientName;
      String? type;
      int? duration;
      await tester.runAsync(() async {
        final slots = await container
            .read(scheduleRepositoryProvider)
            .watchToday()
            .first;
        final consult = slots.firstWhere((s) => s.time == '17:00');
        clientName = consult.clientName;
        type = consult.type;
        duration = consult.durationMinutes;
      });

      expect(clientName, '신규 고객'); // not reassigned to 김민수
      expect(type, '상담');
      expect(duration, 30);
    });

    testWidgets('unsupported program action does not call chat repository', (
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
      await goTo(tester, AppRoutes.schedule);

      await tester.tap(find.text('김민수')); // 완료 session with a program
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('오늘 PT 프로그램 전송'),
        150,
      );
      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsNothing);
      expect(find.text('김민수님에게 전송됨'), findsNothing);
    });

    testWidgets('a failed save shows a snackbar and keeps the sheet open', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          scheduleRepositoryProvider.overrideWith(
            (ref) =>
                _ThrowingScheduleRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.schedule);

      await tester.tap(find.text('새 일정'));
      await settle(tester);
      await tester.tap(find.text('추가하기'));
      await settle(tester);

      expect(find.text('일정 저장에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
      // Sheet stays open (its title is still present) so input isn't lost.
      expect(find.text('새 일정 추가'), findsOneWidget);
    });

    testWidgets('a failed completion keeps the session 예정 and shows an error', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          scheduleRepositoryProvider.overrideWith(
            (ref) =>
                _ThrowingScheduleRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.schedule);

      await tester.scrollUntilVisible(find.text('박성호'), 120); // 예정 session
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('session-complete-chip')),
        120,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('session-complete-chip')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('session-complete-chip')),
      );
      await settle(tester);
      await tester.tap(find.text('완료 처리'));
      await settle(tester);

      // The exception is caught: an error snackbar shows and the card is
      // still 예정 (its ✓ 완료 action remains) (review PR 237).
      expect(find.text('완료 처리에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed delete shows a snackbar', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          scheduleRepositoryProvider.overrideWith(
            (ref) =>
                _ThrowingScheduleRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.schedule);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('삭제'), 120);
      await tester.ensureVisible(find.text('삭제'));
      await tester.pump();
      await tester.tap(find.text('삭제'));
      await settle(tester);
      await tester.tap(find.text('삭제').last); // confirm in dialog
      await settle(tester);

      expect(find.text('일정 삭제에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
    });
  });
}
