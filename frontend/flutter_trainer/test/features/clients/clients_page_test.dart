import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

class _ReadOnlyClientRepository extends DriftClientRepository {
  const _ReadOnlyClientRepository(super.db);

  @override
  bool get supportsRosterMutations => false;
}

void main() {
  group('ClientRepository', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('watchClients returns the 3 seeded clients in order', () async {
      final clients = await DriftClientRepository(db).watchClients().first;
      expect(clients.map((c) => c.name).toList(), <String>[
        '김민수',
        '이지수',
        '박성호',
      ]);
    });

    test('sodiumOverBudget flags only clients above 2000mg', () async {
      final clients = await DriftClientRepository(db).watchClients().first;
      expect(
        clients.where((c) => c.sodiumOverBudget).map((c) => c.name).toSet(),
        <String>{'김민수', '박성호'}, // 2100, 2400; 이지수 1800 is under
      );
    });

    test('addClient appends a fresh profile after the seeded roster', () async {
      final repo = DriftClientRepository(db);
      await repo.addClient(name: '  최수진  ', goal: '체중 감량');

      final clients = await repo.watchClients().first;
      expect(clients.length, 4);
      final added = clients.last; // large sortOrder appends
      expect(added.name, '최수진'); // trimmed
      expect(added.avatar, '최');
      expect(added.goal, '체중 감량');
      expect(added.active, isTrue);
      expect(added.sodiumMg, 0);
      expect(added.weekCompletion, List<int>.filled(7, 0));
      expect(added.id.startsWith('seed-'), isFalse); // survives re-seed
    });

    test(
      'addClient ignores an empty name and defaults an empty goal',
      () async {
        final repo = DriftClientRepository(db);
        expect(await repo.addClient(name: '   ', goal: '아무거나'), isFalse);
        expect((await repo.watchClients().first).length, 3);

        expect(await repo.addClient(name: '박도윤', goal: '  '), isTrue);
        final clients = await repo.watchClients().first;
        expect(clients.last.goal, '목표 설정 전');
      },
    );

    test('addClient rejects a duplicate name', () async {
      final repo = DriftClientRepository(db);

      // Schedules resolve their client by NAME, so a second 김민수 could
      // receive the first one's chat/운동기록 (review PR 243).
      expect(await repo.addClient(name: '김민수', goal: '중복'), isFalse);
      expect(await repo.addClient(name: '  김민수  ', goal: '공백 차이'), isFalse);
      expect(await repo.addClient(name: '김민수 ', goal: '후행 공백'), isFalse);
      expect((await repo.watchClients().first).length, 3); // nothing added

      // A genuinely new name still registers, and is then itself taken.
      expect(await repo.addClient(name: '최수진', goal: '체중 감량'), isTrue);
      expect(await repo.addClient(name: '최수진', goal: '또'), isFalse);
      expect((await repo.watchClients().first).length, 4);

      expect(await repo.clientNameExists('김민수'), isTrue);
      expect(await repo.clientNameExists('없는사람'), isFalse);
    });

    test('concurrent addClient of the same name inserts exactly one', () async {
      final repo = DriftClientRepository(db);

      // Fire both adds without awaiting between them: the check and the
      // insert share one transaction, so only one can pass the duplicate
      // guard even when they race (review PR 243).
      final results = await Future.wait(<Future<bool>>[
        repo.addClient(name: '한지민', goal: 'A'),
        repo.addClient(name: '한지민', goal: 'B'),
      ]);

      expect(results.where((r) => r).length, 1); // exactly one succeeded
      final matches = (await repo.watchClients().first)
          .where((c) => c.name == '한지민')
          .toList();
      expect(matches.length, 1); // and only one row exists
    });

    test('setClientActive flips the 활성/휴면 state', () async {
      final repo = DriftClientRepository(db);
      expect(repo.supportsRosterMutations, isTrue);
      await repo.setClientActive('seed-client-1', false);
      var clients = await repo.watchClients().first;
      expect(clients.firstWhere((c) => c.name == '김민수').active, isFalse);

      await repo.setClientActive('seed-client-1', true);
      clients = await repo.watchClients().first;
      expect(clients.firstWhere((c) => c.name == '김민수').active, isTrue);
    });

    // 예약 수는 이제 로스터가 아니라 오늘 스케줄에서 파생된다(#387).
    // 배지 계산은 todayReservationCountProvider 테스트가 덮고, 날짜 필터링은
    // ScheduleRepository.watchToday 테스트(schedule_page_test)가 덮는다.
    test('오늘 스케줄에서 공백을 뺀 수가 예약 수가 된다', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          scheduleRepositoryProvider.overrideWithValue(
            DriftScheduleRepository(db),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(todayScheduleProvider.future);
      expect(container.read(todayReservationCountProvider).value, 4);
    });

    test('스케줄을 못 읽으면 0 이 아니라 값 없음으로 남는다', () async {
      // 0 을 내보내면 "오늘 예약 0건" 이라는 틀린 사실이 된다 — 배지를 숨겨야 한다.
      final container = ProviderContainer(
        overrides: <Override>[
          todayScheduleProvider.overrideWith(
            (ref) => Stream<List<ScheduleSession>>.error(
              StateError('schedule unavailable'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(todayScheduleProvider.future),
        throwsStateError,
      );
      expect(container.read(todayReservationCountProvider).valueOrNull, isNull);
    });
  });

  group('ClientsPage', () {
    testWidgets('renders the 3 clients, AI summary count, and badge', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      // The roster header states the size; the coaching signals
      // (나트륨 초과, 오늘 예약) now live on the 대시보드, not here.
      expect(find.text('고객'), findsWidgets);
      expect(find.text('3명 · 활성 2명'), findsOneWidget);

      // Priority order: sodium-over clients (김민수, 박성호) come first;
      // 이지수 is last and lazily built, so scroll to reach her.
      expect(find.text('김민수'), findsOneWidget);
      expect(find.text('박성호'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('이지수'), 150);
      expect(find.text('이지수'), findsOneWidget);
    });

    testWidgets('unread badges show and clear after reading the thread', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      // 이지수와 박성호가 각각 1건씩 답장을 기다린다. 김민수의 스레드는
      // 이미 답장·읽음 처리된 상태로 시드된다.
      expect(find.text('1'), findsNWidgets(2));

      // Open 박성호's chat, then come back — his badge cleared, 이지수's
      // stays. Opening the client lands on 개요, which does NOT mark the
      // thread read; the badge clears only once the messages are on screen.
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-3', section: 'chat'),
      );
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await settle(tester);

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('tapping a client card opens the detail screen', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('김민수'));
      await settle(tester);

      // Detail opened — its 개요/채팅/식단/운동/루틴 sub-tabs are unique to it.
      expect(find.text('개요'), findsOneWidget);
      expect(find.text('채팅'), findsOneWidget);
      expect(find.text('운동'), findsOneWidget);
    });

    testWidgets('신규 고객 등록 adds a client to the list', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('신규 고객'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '최수진');
      await tester.enterText(find.byType(TextField).last, '체중 감량');
      await tester.tap(find.text('등록하기'));
      await settle(tester);

      // New client appended at the end of the list (0 data, no badge).
      await tester.scrollUntilVisible(find.text('최수진'), 150);
      expect(find.text('최수진'), findsOneWidget);
      expect(find.text('아직 대화가 없어요'), findsOneWidget);
    });

    testWidgets('registering a duplicate name is blocked with an error', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('신규 고객'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '김민수');
      await tester.tap(find.text('등록하기'));
      await settle(tester);

      // Sheet stays open with an inline error; no second 김민수 created.
      expect(find.text('이미 같은 이름의 고객이 있어요'), findsOneWidget);
      expect(find.text('신규 고객 등록'), findsOneWidget);
    });

    testWidgets('the detail header chip toggles 활성/휴면', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('김민수'));
      await settle(tester);
      expect(find.text('활성'), findsOneWidget);

      await tester.tap(find.text('활성'));
      await settle(tester);
      expect(find.text('휴면'), findsOneWidget);

      await tester.tap(find.text('휴면'));
      await settle(tester);
      expect(find.text('활성'), findsOneWidget);
    });

    testWidgets('read-only repositories disable every roster mutation entry', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
        extraOverrides: [
          clientRepositoryProvider.overrideWith(
            (ref) => _ReadOnlyClientRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );

      await tester.scrollUntilVisible(find.text('박성호'), 150);
      expect(find.text('신규 고객'), findsNothing);

      await tester.tap(find.text('박성호'));
      await settle(tester);

      final statusInkWell = find.byKey(
        const ValueKey<String>('client-status-toggle'),
      );
      expect(statusInkWell, findsOneWidget);
      expect(tester.widget<InkWell>(statusInkWell).onTap, isNull);
    });
  });
}
