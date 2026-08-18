import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

import '../../helpers/pump_app.dart';

/// 취소·노쇼 — 삭제와 갈라진 동작과 그 기록. (#871)
void main() {
  group('DriftScheduleRepository 상태 전이', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });

    tearDown(() => db.close());

    Future<ScheduleSession> upcoming(DriftScheduleRepository repo) async {
      final today = await repo.watchToday().first;
      return today.firstWhere((session) => session.isUpcoming);
    }

    test('취소는 행을 남긴다 — 삭제와 다른 동작이다', () async {
      final repo = DriftScheduleRepository(db);
      final session = await upcoming(repo);

      await repo.cancelSession(session.id, source: CancellationSource.member);

      final after = await repo.watchToday().first;
      final stored = after.firstWhere((item) => item.id == session.id);
      expect(stored.isCancelled, isTrue);
      expect(stored.isUpcoming, isFalse);
      expect(stored.isFinished, isTrue);
    });

    test('노쇼도 행을 남기고 취소와 구분된다', () async {
      final repo = DriftScheduleRepository(db);
      final session = await upcoming(repo);

      await repo.markNoShow(session.id);

      final stored = (await repo.watchToday().first).firstWhere(
        (item) => item.id == session.id,
      );
      expect(stored.isNoShow, isTrue);
      expect(stored.isCancelled, isFalse);
    });

    test('이미 마무리된 세션은 다른 결말로 바뀌지 않는다', () async {
      final repo = DriftScheduleRepository(db);
      final session = await upcoming(repo);

      await repo.cancelSession(session.id, source: CancellationSource.trainer);
      // 실서버는 409 로 막고, 데모는 조용히 아무것도 하지 않는다 — 어느 쪽이든
      // 취소한 세션이 노쇼로 뒤집히지 않는 것이 규칙이다.
      await repo.markNoShow(session.id);

      final stored = (await repo.watchToday().first).firstWhere(
        (item) => item.id == session.id,
      );
      expect(stored.isCancelled, isTrue);
    });

    test('삭제는 여전히 행을 없앤다', () async {
      final repo = DriftScheduleRepository(db);
      final session = await upcoming(repo);

      await repo.deleteSession(session.id);

      final after = await repo.watchToday().first;
      expect(after.where((item) => item.id == session.id), isEmpty);
    });
  });

  group('스케줄 화면', () {
    Future<void> openSchedule(WidgetTester tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.schedule,
      );
    }

    Future<void> openSession(WidgetTester tester, String name) async {
      await tester.scrollUntilVisible(find.text(name), 120);
      await tester.ensureVisible(find.text(name));
      await tester.pump();
      await tester.tap(find.text(name));
      await tester.pump();
    }

    Future<void> tapChip(WidgetTester tester, String key) async {
      final chip = find.byKey(ValueKey<String>(key));
      await tester.scrollUntilVisible(chip, 120);
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await settle(tester);
    }

    testWidgets('취소는 주체를 고르기 전에는 저장되지 않는다', (tester) async {
      await openSchedule(tester);
      await openSession(tester, '박성호');
      await tapChip(tester, 'session-cancel-chip');

      // 기본 주체가 없다 — 무엇이든 기본으로 저장되면 그 값이 사실인지 알 수 없다.
      final confirm = find.byKey(
        const ValueKey<String>('session-cancel-confirm'),
      );
      expect(tester.widget<ActionButton>(confirm).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey<String>('cancel-source-member')));
      await settle(tester);
      expect(tester.widget<ActionButton>(confirm).onPressed, isNotNull);
    });

    testWidgets('취소한 세션은 목록에 남고 상태와 기록을 보여 준다', (tester) async {
      await openSchedule(tester);
      await openSession(tester, '박성호');
      await tapChip(tester, 'session-cancel-chip');

      await tester.tap(find.byKey(const ValueKey<String>('cancel-source-member')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('cancel-reason-input')),
        '고객 출장',
      );
      await tester.tap(find.byKey(const ValueKey<String>('session-cancel-confirm')));
      await settle(tester);

      // 삭제가 아니다 — 그 자리에 남아 취소로 보인다.
      expect(find.text('박성호'), findsOneWidget);
      expect(find.text('취소'), findsWidgets);
      // 마무리된 세션에는 완료·취소·노쇼 동작이 더 이상 나오지 않는다.
      expect(
        find.byKey(const ValueKey<String>('session-cancel-chip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('session-complete-chip')),
        findsNothing,
      );
    });

    testWidgets('노쇼는 확인을 거쳐 기록된다', (tester) async {
      await openSchedule(tester);
      await openSession(tester, '박성호');
      await tapChip(tester, 'session-no-show-chip');

      await tester.tap(
        find.byKey(const ValueKey<String>('session-no-show-confirm')),
      );
      await settle(tester);

      expect(find.text('박성호'), findsOneWidget);
      expect(find.text('노쇼'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('session-no-show-chip')),
        findsNothing,
      );
    });

    testWidgets('삭제 확인 문구가 취소·노쇼를 가리킨다', (tester) async {
      await openSchedule(tester);
      await openSession(tester, '박성호');
      final delete = find.text('삭제');
      await tester.scrollUntilVisible(delete.first, 120);
      await tester.ensureVisible(delete.first);
      await tester.pump();
      await tester.tap(delete.first);
      await settle(tester);

      // 잘못 만든 일정과 진행되지 않은 PT 를 가르는 문장이다(#871).
      expect(
        find.textContaining('취소·노쇼로 남기세요'),
        findsOneWidget,
      );
    });
  });
}
