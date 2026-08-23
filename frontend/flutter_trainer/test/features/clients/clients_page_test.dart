import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/clients/domain/repositories/client_data_refresher.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
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

/// 로스터 목록을 [finder] 가 그려질 때까지 끌어 내린다.
///
/// 목록은 지연 생성이라 화면 밖 카드가 트리에 아예 없다. 아래쪽에 선 고객을
/// 단언하려면 먼저 그려지게 해야 한다 — `.last`·`.first` 를 붙인 finder 를
/// 그대로 넘기면 아직 한 건도 없는 동안 `Bad state: No element` 로 깨진다.
Future<void> scrollToClient(
  WidgetTester tester,
  Finder finder,
) => tester.scrollUntilVisible(
  finder,
  150,
  scrollable: find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first,
);

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

    // 배지는 '남은 일감' 을 말한다. 시드의 오늘은 완료 2 · 공백 2 · 예정 2 라
    // 예약 수(4)와 배지 수(2)는 서로 달라야 맞다(#860).
    test('사이드바 배지는 완료한 세션을 세지 않는다', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          scheduleRepositoryProvider.overrideWithValue(
            DriftScheduleRepository(db),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sessions = await container.read(todayScheduleProvider.future);
      expect(sessions.where((s) => s.isDone).length, 2, reason: '시드 전제');

      expect(container.read(todayPendingSessionCountProvider).value, 2);
      expect(container.read(todayReservationCountProvider).value, 4);
    });

    test('스케줄을 못 읽으면 배지도 값 없음으로 남는다', () async {
      // 예약 수와 같은 규약 — 0 을 내보내면 "남은 일정 없음" 이라는 틀린
      // 사실이 되고, 화면은 배지를 감추는 대신 0 을 그린다.
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
      expect(
        container.read(todayPendingSessionCountProvider).valueOrNull,
        isNull,
      );
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

        expect(find.byType(ClientSearchBar), findsOneWidget);
        expect(find.text('고객 관리'), findsOneWidget);
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
      expect(find.text('오늘 섭취 칼로리'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('client-data-refresh')),
      );
      await settle(tester);

      expect(repository.clientRefreshes, <String>['seed-client-1']);
      expect(find.text('오늘 섭취 칼로리'), findsOneWidget);
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
      expect(find.text('고객 관리'), findsWidgets);
      expect(find.text('15명 · 활성 13명'), findsWidgets);

      // Priority order: sodium-over clients come first, so a client who
      // is under target is further down a now-long, lazily built list.
      // 같은 신호를 든 고객끼리는 마지막 대화가 새로운 쪽이 앞이라, 사흘 전
      // 대화가 마지막인 박성호는 첫 화면 아래에 선다.
      expect(find.text('김민수'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('clients-roster-search')),
        findsNothing,
      );
      expect(find.byType(ClientSearchBar), findsOneWidget);
      await scrollToClient(tester, find.text('박성호'));
      expect(find.text('박성호'), findsOneWidget);
      await scrollToClient(tester, find.text('이지수'));
      expect(find.text('이지수'), findsWidgets);
    });

    testWidgets('전체 보기 clears the URL and local search filters', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientsFiltered('attention'),
      );

      await tester.tap(find.text('전체 보기'));
      await settle(tester);

      expect(find.text('김민수'), findsOneWidget);
    });

    testWidgets('고객 목록은 메시지 미리보기와 안 읽은 배지를 노출하지 않는다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await scrollToClient(tester, find.text('박성호'));
      final sunghoCard = find.ancestor(
        of: find.text('박성호'),
        matching: find.byType(ClientCard),
      );
      expect(
        find.descendant(of: sunghoCard, matching: find.text('1')),
        findsNothing,
      );
      expect(
        find.descendant(of: sunghoCard, matching: find.text('이번 주 운동 못했어요...')),
        findsNothing,
      );
      expect(
        find.descendant(of: sunghoCard, matching: find.textContaining('세')),
        findsOneWidget,
      );
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

      // Detail opened — both evidence tabs and the quick actions are
      // unique to it. 신체·목표 now lives in the merged dialog, not a
      // button of its own (#1024), and 메모 is icon-only.
      expect(find.text('식단'), findsOneWidget);
      expect(find.text('운동'), findsOneWidget);
      expect(find.text('리포트'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('client-detail-open-memo')),
        findsOneWidget,
      );
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

      // New client appended at the end of the list. Customer cards show
      // identity details instead of chat placeholders or unread badges.
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
      final card = find.ancestor(
        of: find.text('최수진').last,
        matching: find.byType(ClientCard),
      );
      expect(
        find.descendant(of: card, matching: find.text('아직 대화가 없어요')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('세')),
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

    testWidgets('a source that cannot add clients still allows 활성/휴면', (
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
      await scrollToClient(tester, clientCard);
      expect(find.text('신규 고객'), findsNothing);

      await tester.tap(clientCard.last);
      await settle(tester);

      // 신규 고객 등록과 활성/휴면은 다른 권한이다 (#707) — 백엔드 로스터에는
      // 고객을 더하는 경로가 없지만 관리 상태 전환은 있다. 한 플래그로 묶여
      // 있던 동안에는 이 배지가 실 API 에서 계속 읽기 전용이었다.
      final statusInkWell = find.byKey(
        const ValueKey<String>('client-status-toggle'),
      );
      expect(statusInkWell, findsOneWidget);
      expect(tester.widget<InkWell>(statusInkWell).onTap, isNotNull);
    });
  });
}
