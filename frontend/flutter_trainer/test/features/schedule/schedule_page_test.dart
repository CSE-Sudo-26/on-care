import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
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
class _ThrowingScheduleRepository extends ScheduleRepository {
  const _ThrowingScheduleRepository(super.db);

  @override
  Future<void> addSession({
    required String date,
    required String clientName,
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
      final slots = await ScheduleRepository(db).watchToday().first;
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

    test('decodes the PT program and expandability rules', () async {
      final slots = await ScheduleRepository(db).watchToday().first;
      final minsu = slots.firstWhere((s) => s.clientName == '김민수');
      expect(minsu.expandable, isTrue); // 완료 + program
      expect(minsu.program.length, 4);
      expect(minsu.program.first.name, '레그프레스');
      expect(minsu.program.first.sets, 3);
      expect(minsu.program.first.weight, '80kg');

      final seongho = slots.firstWhere((s) => s.clientName == '박성호');
      expect(seongho.expandable, isTrue); // 예정 now opens (plan preview)
      expect(seongho.isUpcoming, isTrue);
      final consult = slots.firstWhere((s) => s.clientName == '신규 회원');
      expect(consult.program, isEmpty);
      expect(consult.expandable, isTrue); // opens with the no-plan hint
    });

    test('addSession inserts an 예정 slot sorted into the timeline', () async {
      final repo = ScheduleRepository(db);
      await repo.addSession(
        date: ymd(DateTime.now()),
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
      final repo = ScheduleRepository(db);
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

    test('completeSession flips 예정 to 완료 and logs the 운동기록', () async {
      final repo = ScheduleRepository(db);
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
      final repo = ScheduleRepository(db);
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
        final repo = ScheduleRepository(db);
        // A booked 예정 session that already carries a note.
        await db
            .into(db.trainerScheduleEntries)
            .insert(
              TrainerScheduleEntriesCompanion.insert(
                id: 'sched-noted',
                date: ymd(DateTime.now()),
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
        final repo = ScheduleRepository(db);
        final before = await repo.watchToday().first;
        final consult = before.firstWhere((s) => s.clientName == '신규 회원');
        final histBefore =
            (await db.select(db.clientRoutineHistory).get()).length;

        await repo.completeSession(consult.id);

        final after = await repo.watchToday().first;
        expect(after.firstWhere((s) => s.clientName == '신규 회원').isDone, isTrue);
        final histAfter =
            (await db.select(db.clientRoutineHistory).get()).length;
        expect(histAfter, histBefore); // no orphan history row
      },
    );

    test('watchDate separates timelines per calendar day', () async {
      final repo = ScheduleRepository(db);
      final tomorrow = ymd(DateTime.now().add(const Duration(days: 1)));

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
      expect(booked, containsAll(<String>[ymd(DateTime.now()), tomorrow]));
    });

    test('completing a non-today session labels its own date', () async {
      final repo = ScheduleRepository(db);
      // A PAST session — completing it retro-logs the class. Future
      // sessions can't be completed (see the next test).
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
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
      final repo = ScheduleRepository(db);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
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

    test('deleteSession removes the slot', () async {
      final repo = ScheduleRepository(db);
      final before = await repo.watchToday().first;
      final target = before.firstWhere((s) => s.clientName == '신규 회원');
      await repo.deleteSession(target.id);
      final after = await repo.watchToday().first;
      expect(after.length, before.length - 1);
      expect(after.where((s) => s.clientName == '신규 회원'), isEmpty);
    });
  });

  group('SchedulePage', () {
    Future<void> openSchedule(WidgetTester tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      await tester.tap(find.text('스케줄')); // bottom-nav label
      await settle(tester);
    }

    testWidgets('renders header, week strip, and the timeline', (tester) async {
      await openSchedule(tester);

      expect(find.textContaining('온케어짐 신촌점'), findsOneWidget);
      expect(find.text('김민수'), findsOneWidget);
      expect(find.text('이지수'), findsOneWidget);
      expect(find.text('1:1 PT · 60분'), findsWidgets);
      expect(find.text('완료'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.text('신규 회원'), 120);
      expect(find.text('박성호'), findsOneWidget);
      expect(find.text('상담 · 30분'), findsOneWidget);
      // Lazy list: off-screen rows are disposed, so assert presence
      // rather than an exact count.
      expect(find.text('빈 시간'), findsWidgets);
      expect(find.text('예정'), findsWidgets);
    });

    testWidgets('completed session expands to program, note, and send flow', (
      tester,
    ) async {
      await openSchedule(tester);

      // Expand 김민수 (완료).
      await tester.tap(find.text('김민수'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('오늘 PT 프로그램 전송'),
        150,
      );
      expect(find.text('레그프레스'), findsOneWidget);
      expect(find.text('카프레이즈'), findsOneWidget);
      expect(find.text('트레이너 메모'), findsOneWidget);
      expect(find.text('무릎 컨디션 양호. 레그프레스 중량 소폭 증가 가능.'), findsOneWidget);

      // Send → confirmation flash → persistent sent state, no re-send.
      // Make sure the button is FULLY on-screen (a partially clipped
      // widget makes tap() miss its hit test).
      await tester.ensureVisible(find.textContaining('오늘 PT 프로그램 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('오늘 PT 프로그램 전송'));
      await tester.pump();
      expect(find.text('✓ 고객 앱으로 전송 완료!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3)); // flash expires
      expect(find.text('✓ 김민수님에게 전송됨'), findsOneWidget);
      expect(find.textContaining('오늘 PT 프로그램 전송'), findsNothing);

      // Tapping the sent button again is a no-op (stays sent).
      await tester.tap(find.text('✓ 김민수님에게 전송됨'));
      await tester.pump();
      expect(find.text('✓ 김민수님에게 전송됨'), findsOneWidget);
    });

    testWidgets('예정 session expands to the plan preview with manage '
        'actions', (tester) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('✎ 수정'), 120);
      expect(find.text('벤치프레스'), findsOneWidget); // planned program
      expect(find.text('삭제'), findsOneWidget);
      expect(find.text('💬 채팅'), findsOneWidget);
    });

    testWidgets('예정 session without a plan shows the no-plan hint', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('신규 회원'), 120);
      await tester.ensureVisible(find.text('신규 회원'));
      await tester.pump();
      await tester.tap(find.text('신규 회원'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('아직 계획된 프로그램이 없어요'), 120);
      expect(find.text('아직 계획된 프로그램이 없어요'), findsOneWidget);
    });

    testWidgets('새 일정 추가 books a session at a 15-minute step', (tester) async {
      await openSchedule(tester);

      await tester.tap(find.text('＋ 새 일정 추가'));
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

    testWidgets('수정 moves 박성호 to a 15-minute step (15:00 → 15:30)', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('✎ 수정'), 120);
      await tester.ensureVisible(find.text('✎ 수정'));
      await tester.pump();
      await tester.tap(find.text('✎ 수정'));
      await settle(tester);

      // Editing stays inside the expanded schedule card and supports memo.
      expect(
        find.byKey(
          const ValueKey<String>('inline-session-editor-seed-schedule-3'),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('schedule-trainer-note')),
        '오른쪽 어깨 가동범위 확인',
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
      expect(find.text('오른쪽 어깨 가동범위 확인'), findsOneWidget);
    });

    testWidgets('삭제 removes the session after confirmation', (tester) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('신규 회원'), 120);
      await tester.ensureVisible(find.text('신규 회원'));
      await tester.pump();
      await tester.tap(find.text('신규 회원'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('삭제'), 120);
      await tester.ensureVisible(find.text('삭제'));
      await tester.pump();
      await tester.tap(find.text('삭제'));
      await settle(tester);
      // Confirm in the dialog (its action is the last 삭제 on screen).
      await tester.tap(find.text('삭제').last);
      await settle(tester);

      expect(find.text('신규 회원'), findsNothing);
    });

    testWidgets('program send does not create a trainer chat bubble', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.tap(find.text('김민수'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('오늘 PT 프로그램 전송'),
        150,
      );
      await tester.ensureVisible(find.textContaining('오늘 PT 프로그램 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('오늘 PT 프로그램 전송'));
      await settle(tester);
      expect(find.text('✓ 김민수님에게 전송됨'), findsOneWidget);

      // Program status stays in the schedule UI rather than appearing as a
      // trainer-authored blue chat bubble.
      await tester.tap(find.text('고객'));
      await settle(tester);
      await tester.tap(find.text('김민수'));
      await settle(tester);
      expect(find.textContaining('📤 오늘 PT 프로그램을 보냈어요'), findsNothing);
    });

    testWidgets('✓ 완료 marks the session done and shows in 운동기록', (
      tester,
    ) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('✓ 완료'), 120);
      await tester.ensureVisible(find.text('✓ 완료'));
      await tester.pump();
      await tester.tap(find.text('✓ 완료'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).last, '벤치 폼 안정적');
      await tester.tap(find.text('완료 처리'));
      await settle(tester);

      // The card flipped to 완료 (the ✓ 완료 action is gone).
      expect(find.text('✓ 완료'), findsNothing);

      // …and the 운동기록 sub-tab shows the fresh PT entry on top.
      await tester.tap(find.text('고객'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('박성호'), 150);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await settle(tester);
      await tester.tap(find.text('운동기록'));
      await settle(tester);
      expect(find.textContaining('(오늘)'), findsWidgets);
      expect(find.text('벤치 폼 안정적'), findsOneWidget);
    });

    testWidgets('a future session offers no ✓ 완료 action', (tester) async {
      await openSchedule(tester);

      // Browse to tomorrow and book a session there.
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.text('${tomorrow.day}').first);
      await settle(tester);
      await tester.tap(find.text('＋ 새 일정 추가'));
      await settle(tester);
      await tester.tap(find.text('추가하기'));
      await settle(tester);

      // Expand the freshly booked 예정 card.
      await tester.tap(find.text('김민수'));
      await tester.pump();

      // Manage actions are there, but 완료 is not — the class is in the
      // future (review PR 245).
      expect(find.text('✎ 수정'), findsOneWidget);
      expect(find.text('💬 채팅'), findsOneWidget);
      expect(find.text('✓ 완료'), findsNothing);
    });

    testWidgets('picking another day browses it; 오늘로 returns to today', (
      tester,
    ) async {
      await openSchedule(tester);
      expect(find.text('김민수'), findsOneWidget);
      // On today, the 오늘로 shortcut is hidden.
      expect(find.text('오늘로'), findsNothing);

      // Default window is centred on today (D-3…D+3); tap tomorrow.
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.text('${tomorrow.day}').first);
      await settle(tester);

      // Tomorrow has no seeded sessions → empty state, and 오늘로 appears.
      expect(find.text('김민수'), findsNothing);
      expect(find.textContaining('이 날짜에는 일정이 없어요'), findsOneWidget);
      expect(find.text('오늘로'), findsOneWidget);

      // Book a session on the browsed day; the empty state clears.
      await tester.tap(find.text('＋ 새 일정 추가'));
      await settle(tester);
      await tester.tap(find.text('추가하기'));
      await settle(tester);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.textContaining('이 날짜에는 일정이 없어요'), findsNothing);

      // 오늘로 → today's seeded timeline is intact and the button hides.
      await tester.tap(find.text('오늘로'));
      await settle(tester);
      expect(find.text('김민수'), findsOneWidget);
      expect(find.text('오늘로'), findsNothing);
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
      expect(find.text('오늘로'), findsOneWidget);
    });

    testWidgets('💬 채팅 jumps to the client detail chat', (tester) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('💬 채팅'), 120);
      await tester.ensureVisible(find.text('💬 채팅'));
      await tester.pump();
      await tester.tap(find.text('💬 채팅'));
      await settle(tester);

      // Full-screen client detail with the chat sub-tab.
      expect(find.text('채팅'), findsOneWidget);
      expect(find.text('운동기록'), findsOneWidget);
      expect(find.textContaining('AI가 박성호님의'), findsOneWidget);
    });

    testWidgets('editing a session whose client is not in the roster keeps '
        'its own values on a no-op save', (tester) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
      );
      await tester.tap(find.text('스케줄'));
      await settle(tester);

      // 신규 회원 (상담, 30분) is booked but is NOT a registered client.
      await tester.scrollUntilVisible(find.text('신규 회원'), 120);
      await tester.ensureVisible(find.text('신규 회원'));
      await tester.pump();
      await tester.tap(find.text('신규 회원'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('✎ 수정'), 120);
      await tester.ensureVisible(find.text('✎ 수정'));
      await tester.pump();
      await tester.tap(find.text('✎ 수정'));
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

      expect(clientName, '신규 회원'); // not reassigned to 김민수
      expect(type, '상담');
      expect(duration, 30);
    });

    testWidgets('program status does not depend on the chat repository', (
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
      await tester.tap(find.text('스케줄'));
      await settle(tester);

      await tester.tap(find.text('김민수')); // 완료 session with a program
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('오늘 PT 프로그램 전송'),
        150,
      );
      await tester.ensureVisible(find.textContaining('오늘 PT 프로그램 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('오늘 PT 프로그램 전송'));
      await settle(tester);

      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsNothing);
      expect(find.text('✓ 김민수님에게 전송됨'), findsOneWidget);
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
      await tester.tap(find.text('스케줄'));
      await settle(tester);

      await tester.tap(find.text('＋ 새 일정 추가'));
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
      await tester.tap(find.text('스케줄'));
      await settle(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120); // 예정 session
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('✓ 완료'), 120);
      await tester.ensureVisible(find.text('✓ 완료'));
      await tester.pump();
      await tester.tap(find.text('✓ 완료'));
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
      await tester.tap(find.text('스케줄'));
      await settle(tester);

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
