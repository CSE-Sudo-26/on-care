import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/clients/domain/repositories/client_data_refresher.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

class _ReadOnlyClientRepository extends DriftClientRepository {
  const _ReadOnlyClientRepository(super.db);

  @override
  bool get supportsRosterMutations => false;
}

class _RecordingRefreshClientRepository extends DriftClientRepository
    implements ClientDataRefresher {
  _RecordingRefreshClientRepository(super.db);

  var allRefreshes = 0;
  final List<String> clientRefreshes = <String>[];

  @override
  void refreshAllClientData() {
    allRefreshes += 1;
  }

  @override
  void refreshClientData(String clientId) {
    clientRefreshes.add(clientId);
  }
}

void main() {
  group('ClientRepository', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('watchClients returns the seeded clients in sortOrder', () async {
      final clients = await DriftClientRepository(db).watchClients().first;
      // Unprioritised order is the seeded order, so the first three are
      // still the original roster the rest of these tests address.
      expect(clients.take(3).map((c) => c.name).toList(), <String>[
        '김민수',
        '이지수',
        '박성호',
      ]);
      expect(clients.length, 15);
    });

    test('sodiumOverBudget flags only clients above 2000mg', () async {
      final clients = await DriftClientRepository(db).watchClients().first;
      // The rule, not a name list — the roster is a fixture that grows.
      for (final c in clients) {
        expect(c.sodiumOverBudget, c.sodiumMg > 2000, reason: c.name);
      }
      // …and the fixture must keep exercising both sides of it.
      expect(clients.where((c) => c.sodiumOverBudget), isNotEmpty);
      expect(clients.where((c) => !c.sodiumOverBudget), isNotEmpty);
    });

    test('addClient appends a fresh profile after the seeded roster', () async {
      final repo = DriftClientRepository(db);
      final seeded = (await repo.watchClients().first).length;
      await repo.addClient(name: '  최수진  ', goal: '체중 감량');

      final clients = await repo.watchClients().first;
      expect(clients.length, seeded + 1);
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
        final seeded = (await repo.watchClients().first).length;
        expect(await repo.addClient(name: '   ', goal: '아무거나'), isFalse);
        expect((await repo.watchClients().first).length, seeded);

        expect(await repo.addClient(name: '박도윤', goal: '  '), isTrue);
        final clients = await repo.watchClients().first;
        expect(clients.last.goal, '목표 설정 전');
      },
    );

    test('addClient rejects a duplicate name', () async {
      final repo = DriftClientRepository(db);
      final seeded = (await repo.watchClients().first).length;

      // Schedules resolve their client by NAME, so a second 김민수 could
      // receive the first one's chat/운동기록 (review PR 243).
      expect(await repo.addClient(name: '김민수', goal: '중복'), isFalse);
      expect(await repo.addClient(name: '  김민수  ', goal: '공백 차이'), isFalse);
      expect(await repo.addClient(name: '김민수 ', goal: '후행 공백'), isFalse);
      expect((await repo.watchClients().first).length, seeded); // nothing added

      // A genuinely new name still registers, and is then itself taken.
      expect(await repo.addClient(name: '최수진', goal: '체중 감량'), isTrue);
      expect(await repo.addClient(name: '최수진', goal: '또'), isFalse);
      expect((await repo.watchClients().first).length, seeded + 1);

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
    for (final entry in <(String, AsyncValue<List<TrainerClient>>)>[
      ('loading', const AsyncLoading<List<TrainerClient>>()),
      (
        'error',
        AsyncError<List<TrainerClient>>(
          StateError('roster unavailable'),
          StackTrace.empty,
        ),
      ),
    ]) {
      testWidgets('${entry.$1} 상태에서도 회원 상세 route를 유지한다', (tester) async {
        await pumpTrainerApp(
          tester,
          token: 'demo-trainer-token',
          at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
          extraOverrides: <Override>[
            prioritizedClientsProvider.overrideWithValue(entry.$2),
          ],
        );

        expect(find.byType(ClientSearchBar), findsNothing);
        expect(find.text('회원 관리'), findsOneWidget);
      });
    }

    testWidgets('re-entering the client branch requests a data refresh', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      late _RecordingRefreshClientRepository repository;

      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
        extraOverrides: <Override>[
          clientRepositoryProvider.overrideWith((ref) {
            repository = _RecordingRefreshClientRepository(
              ref.watch(appDatabaseProvider),
            );
            return repository;
          }),
        ],
      );
      expect(find.text('김민수'), findsOneWidget);

      await goTo(tester, AppRoutes.dashboard);
      await goTo(tester, AppRoutes.clients);

      expect(repository.allRefreshes, 1);
      expect(find.text('김민수'), findsOneWidget);
    });

    testWidgets('the detail refresh action targets the selected client', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      late _RecordingRefreshClientRepository repository;

      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'diet'),
        extraOverrides: <Override>[
          clientRepositoryProvider.overrideWith((ref) {
            repository = _RecordingRefreshClientRepository(
              ref.watch(appDatabaseProvider),
            );
            return repository;
          }),
        ],
      );
      expect(find.text('오늘 영양 요약'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('client-data-refresh')),
      );
      await settle(tester);

      expect(repository.clientRefreshes, <String>['seed-client-1']);
      expect(find.text('오늘 영양 요약'), findsOneWidget);
    });

    testWidgets('renders the roster with its size and priority order', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      // The roster header states the size; the coaching signals
      // (나트륨 초과, 오늘 예약) now live on the 대시보드, not here.
      expect(find.text('회원 관리'), findsWidgets);
      expect(find.text('15명 · 활성 13명'), findsWidgets);

      // Priority order: sodium-over clients come first, so a client who
      // is under target is further down a now-long, lazily built list.
      expect(find.text('김민수'), findsOneWidget);
      expect(find.text('박성호'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('이지수'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('이지수'), findsWidgets);
    });

    testWidgets('unread badges show and clear after reading the thread', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      // Scoped to each card rather than counting '1' across the roster:
      // several members are waiting on a reply now, and the list is long
      // enough that what is built depends on scroll position.
      Finder badgeOf(String name) => find.descendant(
        of: find.ancestor(
          of: find.text(name),
          matching: find.byType(ClientCard),
        ),
        matching: find.text('1'),
      );

      // 박성호 is waiting; 김민수's thread is seeded already answered.
      expect(badgeOf('박성호'), findsOneWidget);
      expect(badgeOf('김민수'), findsNothing);

      // Open 박성호's chat, then come back — his badge cleared. The badge
      // clears once the messages are on screen.
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-3', section: 'chat'),
      );
      await goTo(tester, AppRoutes.clients);
      await settle(tester);

      expect(badgeOf('박성호'), findsNothing);
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

      // Detail opened — both evidence sections and the standalone message
      // action are unique to it.
      expect(find.text('식단'), findsOneWidget);
      expect(find.text('운동'), findsOneWidget);
      expect(find.text('메시지'), findsOneWidget);
    });

    testWidgets('신규 고객 등록 adds a client to the list', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('신규 고객'));
      await settle(tester);

      final sheetFields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheetFields.first, '최수진');
      await tester.enterText(sheetFields.last, '체중 감량');
      await tester.tap(find.text('등록하기'));
      await settle(tester);

      // New client appended at the end of the list (0 data, no badge).
      // Scoped to her own card: a seeded brand-new client carries the
      // same "아직 대화가 없어요" placeholder.
      await tester.scrollUntilVisible(
        find.text('최수진'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('최수진'), findsWidgets);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('최수진').last,
            matching: find.byType(ClientCard),
          ),
          matching: find.text('아직 대화가 없어요'),
        ),
        findsOneWidget,
      );
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

      final sheetFields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheetFields.first, '김민수');
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

      final clientCard = find.byKey(
        const ValueKey<String>('client-seed-client-3'),
      );
      await tester.scrollUntilVisible(
        clientCard.last,
        150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('신규 고객'), findsNothing);

      await tester.tap(clientCard.last);
      await settle(tester);

      final statusInkWell = find.byKey(
        const ValueKey<String>('client-status-toggle'),
      );
      expect(statusInkWell, findsOneWidget);
      expect(tester.widget<InkWell>(statusInkWell).onTap, isNull);
    });
  });
}
