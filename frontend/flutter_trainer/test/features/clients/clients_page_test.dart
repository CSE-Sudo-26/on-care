import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';
import 'package:oncare_trainer/features/clients/domain/repositories/client_data_refresher.dart';
import 'package:oncare_trainer/features/clients/presentation/controllers/roster_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

/// [ClientInviteRepository] 가 꺼진 빌드 — 신규 고객 등록 진입점 자체가
/// 없는 상태를 흉내낸다.
class _NoInviteClientInviteRepository implements ClientInviteRepository {
  const _NoInviteClientInviteRepository();

  @override
  bool get supportsInvites => false;

  @override
  bool get connectsImmediately => false;

  @override
  Future<MemberLookup> lookup(String memberId) async =>
      throw const NotFoundError();

  @override
  Future<ClientInvite> invite(String memberId, {String? message}) async =>
      throw const ValidationError();

  @override
  Future<List<ClientInvite>> listSent({String status = 'pending'}) async =>
      const <ClientInvite>[];

  @override
  Future<void> cancel(String inviteId) async {}
}

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
Future<void> scrollToClient(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first,
  );
  // 이행률 바가 붙은 카드는 일부만 보여도 이미 트리에 있다. 가운데를 눌러도
  // 화면 밖 좌표가 되지 않도록 카드 전체를 실제 viewport 안으로 맞춘다.
  await tester.ensureVisible(finder.last);
  await tester.pumpAndSettle();
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

    test('removeClient removes the client from the demo roster', () async {
      final repo = DriftClientRepository(db);
      await repo.removeClient('seed-client-1');

      final clients = await repo.watchClients().first;
      expect(clients.any((c) => c.id == 'seed-client-1'), isFalse);
      expect(
        await (db.select(
          db.trainerScheduleEntries,
        )..where((t) => t.clientId.equals('seed-client-1'))).get(),
        isEmpty,
      );
      expect(
        await (db.select(
          db.clientAiRoutines,
        )..where((t) => t.clientId.equals('seed-client-1'))).get(),
        isEmpty,
      );
      expect(
        await (db.select(
          db.reportFeedbackDrafts,
        )..where((t) => t.clientId.equals('seed-client-1'))).get(),
        isEmpty,
      );
      expect(
        await (db.select(
          db.clientChatMessages,
        )..where((t) => t.clientId.equals('seed-client-1'))).get(),
        isEmpty,
      );
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

    testWidgets('신규 고객 등록 — 회원 ID로 아직 연결되지 않은 회원을 찾아 연결한다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('신규 고객 등록'));
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('client-connect-member-id')),
        'USER-8F2A41C9D6E3', // 대소문자는 같은 회원 ID다
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('client-connect-lookup')),
      );
      await settle(tester);

      // 확인 카드는 회원이 이미 등록해 둔 값을 보여준다 — 트레이너가
      // 여기서 성별·나이를 입력하는 것이 아니다.
      expect(find.text('이수아'), findsOneWidget);
      expect(find.text('이 고객이 맞나요?'), findsOneWidget);
      expect(find.text('고객 등록'), findsOneWidget);

      await tester.ensureVisible(find.text('고객 등록'));
      await tester.tap(find.text('고객 등록'));
      await settle(tester);

      // 연결 성공 후 고객 리스트가 (재시작 없이) 즉시 반영된다 — 실제
      // repository/drift 스트림 결과이지, 화면에 끼워 넣은 값이 아니다.
      final card = find.byKey(
        const ValueKey<String>('client-user-8f2a41c9d6e3'),
      );
      await scrollToClient(tester, card);
      expect(
        find.descendant(of: card, matching: find.text('이수아')),
        findsOneWidget,
      );
      // 연결된 프로필은 데모 명부가 가진 실제 성별·나이를 그대로 쓴다 —
      // 회원 id 해시로 지어낸 값이 아니다(#960 과 같은 폴백을 타지 않는다).
      expect(
        find.descendant(of: card, matching: find.textContaining('여성')),
        findsOneWidget,
      );
    });

    testWidgets('이미 연결된 회원 ID를 입력하면 중복 안내가 뜬다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('신규 고객 등록'));
      await settle(tester);

      // 이미 담당 중인 김민수(seed-client-1)의 회원 ID다 — 회원 앱 MY 탭이
      // 데모 모드에서 보여주는 것과 같은 값이다.
      await tester.enterText(
        find.byKey(const ValueKey<String>('client-connect-member-id')),
        'user-7d4e9a2c5f18',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('client-connect-lookup')),
      );
      await settle(tester);

      expect(find.text('김민수'), findsWidgets);
      expect(find.text('이미 담당하고 있는 회원이에요'), findsOneWidget);
      // 이유만 보여 주고 끝내지 않는다 — 연결 버튼 자체가 없다.
      expect(find.text('고객 등록'), findsNothing);
    });

    testWidgets('존재하지 않는 회원 ID는 찾을 수 없음으로 안내한다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(find.text('신규 고객 등록'));
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('client-connect-member-id')),
        'user-no-such-member',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('client-connect-lookup')),
      );
      await settle(tester);

      expect(find.text('그 회원 ID를 쓰는 회원을 찾지 못했어요'), findsOneWidget);
      expect(find.text('고객 등록'), findsNothing);
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
          clientInviteRepositoryProvider.overrideWithValue(
            const _NoInviteClientInviteRepository(),
          ),
        ],
      );

      final clientCard = find.byKey(
        const ValueKey<String>('client-seed-client-3'),
      );
      await scrollToClient(tester, clientCard);
      expect(find.text('신규 고객 등록'), findsNothing);

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

    // #1026: 툴바 관리 필터가 단일 선택 팝업에서 복수 선택 chip 으로 바뀌었다.
    testWidgets('나트륨 초과 필터를 고르면 해당 고객만 남는다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-sodiumOver')),
      );
      await settle(tester);

      // sodiumOverBudget (2000mg 초과) 재사용 — 시드의 박성호(2400mg)는
      // 남고, 이지수(1800mg)는 사라진다. (김민수는 공유 픽스처가 오늘 값을
      // 정하는 회원이라 날짜별로 값이 바뀌어 이 비교엔 쓰지 않는다 — #757.)
      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      final seonghoCard = find.byKey(
        const ValueKey<String>('client-seed-client-3'),
      );
      await scrollToClient(tester, seonghoCard);
      expect(seonghoCard, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('client-seed-client-2')),
        findsNothing,
      );

      // 같은 chip 을 다시 누르면 선택이 풀린다 — 다중 선택의 개별 제거.
      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-sodiumOver')),
      );
      await settle(tester);
      expect(find.text('필터'), findsWidgets);
      expect(find.text('필터 1'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
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
      expect(find.text('이지수'), findsOneWidget);
    });

    testWidgets('당류 초과 필터를 고르면 해당 고객만 남는다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-sugarOver')),
      );
      await settle(tester);

      // sugarOverBudget (50g 초과) — 강서연(74g)은 남고, 이지수(38g)는
      // 사라진다.
      expect(find.text('강서연'), findsOneWidget);
      expect(find.text('이지수'), findsNothing);
    });

    testWidgets('이행률 저조 배지 필터는 같은 ClientAlert 기준을 쓴다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
        // 주간 계열이 모두 채워진 시점으로 고정해 실행 요일에 따라
        // 저조 배지가 달라지지 않게 한다.
        seedClock: DateTime(2026, 8, 16),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-lowCompletion')),
      );
      await settle(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();

      final lowCompletionCard = find.byKey(
        const ValueKey<String>('client-seed-client-9'),
      );
      await scrollToClient(tester, lowCompletionCard);
      expect(lowCompletionCard, findsOneWidget); // 배준혁: 주간 평균 60% 미만
      expect(
        find.byKey(const ValueKey<String>('client-seed-client-2')),
        findsNothing,
      ); // 이지수: 이행률 정상
    });

    testWidgets('답장 대기 배지 필터는 실제 안 읽은 메시지 수를 쓴다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
        seedClock: DateTime(2026, 8, 16),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-unanswered')),
      );
      await settle(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();

      final unansweredCard = find.byKey(
        const ValueKey<String>('client-seed-client-8'),
      );
      await scrollToClient(tester, unansweredCard);
      expect(unansweredCard, findsOneWidget); // 오세라: 회원이 마지막으로 보냄
      expect(
        find.byKey(const ValueKey<String>('client-seed-client-3')),
        findsNothing,
      ); // 박성호: 트레이너가 답장함
    });

    testWidgets('모든 필터는 서로 해제하지 않고 독립적으로 선택된다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      for (final filter in RosterManagementFilter.values) {
        await tester.tap(
          find.byKey(ValueKey<String>('management-filter-${filter.name}')),
        );
        await settle(tester);
      }
      expect(find.text('필터 7'), findsOneWidget);

      // 한 조건만 다시 누르면 나머지 선택은 그대로 유지된다.
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-attention')),
      );
      await settle(tester);
      expect(find.text('필터 6'), findsOneWidget);
    });

    testWidgets('복수 필터는 OR 로 합쳐지고 전체 초기화로 한 번에 풀린다', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clients,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      // 활성 + 휴면을 동시에 고르면 "둘 다 보기" 다 — AND 였다면 서로
      // 배타적인 두 값이라 아무도 안 남았을 것이다.
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-active')),
      );
      await settle(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('management-filter-dormant')),
      );
      await settle(tester);

      expect(find.text('필터 2'), findsOneWidget);
      expect(find.text('전체 초기화'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('client-seed-client-1')),
        findsOneWidget,
      ); // 활성
      final seonghoCard = find.byKey(
        const ValueKey<String>('client-seed-client-3'),
      );
      await scrollToClient(tester, seonghoCard);
      expect(seonghoCard, findsOneWidget); // 휴면

      await tester.tap(
        find.byKey(const ValueKey<String>('clients-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 초기화'));
      await settle(tester);

      // 초기화 버튼은 선택이 없을 때는 그려지지 않는다.
      expect(find.text('전체 초기화'), findsNothing);
    });
  });
}
