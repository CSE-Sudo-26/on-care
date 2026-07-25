import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';

import '../../helpers/pump_app.dart';

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
      expect(seongho.expandable, isFalse); // 예정 — not expandable
      final consult = slots.firstWhere((s) => s.clientName == '신규 회원');
      expect(consult.program, isEmpty);
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
      expect(find.text('빈 시간'), findsNWidgets(2));
      expect(find.text('예정'), findsNWidgets(2));
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

    testWidgets('예정 sessions do not expand', (tester) async {
      await openSchedule(tester);

      await tester.scrollUntilVisible(find.text('박성호'), 120);
      await tester.tap(find.text('박성호'));
      await tester.pump();
      expect(find.text('벤치프레스'), findsNothing);
    });
  });
}
