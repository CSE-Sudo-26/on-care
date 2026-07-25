import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';

import '../../helpers/pump_app.dart';

/// A repository whose writes always fail — to exercise error handling.
class _ThrowingScheduleRepository extends ScheduleRepository {
  const _ThrowingScheduleRepository(super.db);

  @override
  Future<void> addSession({
    required String clientName,
    required String time,
    required String type,
    required int durationMinutes,
  }) async => throw Exception('add failed');

  @override
  Future<void> deleteSession(String id) async => throw Exception('del failed');
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
      );
      final after = await repo.watchToday().first;
      final moved = after.firstWhere((s) => s.clientName == '박성호');
      expect(moved.time, '19:30');
      expect(moved.durationMinutes, 90);
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

      // Change 00분 → 30분 in the time picker and save.
      await tester.tap(find.text('00분'));
      await settle(tester);
      await tester.tap(find.text('30분').last);
      await settle(tester);
      await tester.tap(find.text('저장하기'));
      await settle(tester);

      expect(find.text('15:30'), findsOneWidget);
      expect(find.text('15:00'), findsNothing);
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
