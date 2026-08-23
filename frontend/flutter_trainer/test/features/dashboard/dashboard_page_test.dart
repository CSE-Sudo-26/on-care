import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/attention_card.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/stat_card.dart';

import '../../helpers/client_factory.dart';
import '../../helpers/pump_app.dart';

/// The 대시보드 against the seeded roster.
///
/// Seed: 3 clients (김민수 3428mg and 박성호 2400mg are over the 2000mg
/// target, 이지수 1800mg is not; 이지수 is 휴면), all three have unread
/// replies (4 in total), and today has 4 booked sessions (6 slots − 2
/// gaps).
void main() {
  Future<void> openDashboard(
    WidgetTester tester, {
    List<Override> extraOverrides = const <Override>[],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.dashboard,
      extraOverrides: extraOverrides,
    );
  }

  /// The location the router is currently showing.
  String currentLocation(WidgetTester tester) {
    final ctx = tester.element(find.byType(Navigator).first);
    return GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.toString();
  }

  /// 오늘 할 일은 카테고리(`dashboard-todo-category-<name>`)를 먼저 보여
  /// 주고, 고르면 그 안에서 미션(`dashboard-mission-<prefix>-...`)이 뜬다.
  Finder findCategoryTile(String categoryName) =>
      find.byKey(ValueKey<String>('dashboard-todo-category-$categoryName'));

  Finder findMissionRow(String prefix) => find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('dashboard-mission-$prefix-');
  });

  Future<void> openTodoCategory(WidgetTester tester, String categoryName) async {
    final tile = findCategoryTile(categoryName);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump();
  }

  /// 주의 고객 검증이 쓰는 고정 로스터. (#907)
  ///
  /// 건강 신호 여덟(나트륨 5 · 당류 1 · 이행률 2)과 답장 대기 둘. 기대값을
  /// 데이터 바로 옆에 두어, 숫자가 어디서 왔는지 읽는 사람이 세어 볼 수 있게 한다.
  ///
  /// 이행률 경고는 `weekCompletion` 을 직접 준다 — 시드처럼 오늘 요일에 따라
  /// 잘리는 값을 쓰면 판정이 요일을 탄다.
  List<Override> attentionRosterOverrides() {
    const List<int> lowWeek = <int>[40, 40, 0, 0, 0, 0, 0];
    final List<TrainerClient> roster = <TrainerClient>[
      for (var i = 0; i < 5; i++)
        makeClient(id: 'sodium-$i', name: '나트륨 고객 $i', sodiumMg: 2500),
      makeClient(id: 'sugar-0', name: '당류 고객', sugarG: 80),
      for (var i = 0; i < 2; i++)
        makeClient(
          id: 'completion-$i',
          name: '이행률 고객 $i',
          weekCompletion: lowWeek,
        ),
      makeClient(id: 'reply-0', name: '답장 고객 0'),
      makeClient(id: 'reply-1', name: '답장 고객 1'),
    ];
    return <Override>[
      clientsProvider.overrideWith(
        (ref) => Stream<List<TrainerClient>>.value(roster),
      ),
      unreadCountsProvider.overrideWith(
        (ref) => Stream<Map<String, int>>.value(const <String, int>{
          'reply-0': 1,
          'reply-1': 2,
        }),
      ),
    ];
  }

  testWidgets('is the landing page after a restored session', (tester) async {
    await openDashboard(tester);
    expect(find.text('대시보드'), findsWidgets);
  });

  testWidgets('a failed summary retries once and renders fresh data', (
    tester,
  ) async {
    final retryGate = Completer<List<TrainerClient>>();
    int attempts = 0;
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.dashboard,
      extraOverrides: <Override>[
        clientsProvider.overrideWith((ref) {
          attempts++;
          if (attempts == 1) {
            return Stream<List<TrainerClient>>.error(
              StateError('internal transport detail'),
            );
          }
          return Stream<List<TrainerClient>>.fromFuture(retryGate.future);
        }),
      ],
    );

    expect(find.text('대시보드를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('internal transport detail'), findsNothing);

    final retry = find.byKey(const ValueKey<String>('dashboard-retry'));
    await tester.tap(retry);
    await tester.pump();
    await tester.tap(retry, warnIfMissed: false);
    await tester.pump();
    expect(attempts, 2, reason: '재시도 중 중복 요청이 시작됐어요');

    retryGate.complete(<TrainerClient>[
      makeClient(name: '복구 고객', sodiumMg: 2500),
    ]);
    await settle(tester);

    // 오늘 할 일이 카테고리 그리드로 접혀 있어 이름은 그 안(고객 피드백
    // 확인)에 들어가야 보인다 — 새로 고쳐 그렸다는 사실은 KPI 로 확인한다.
    final myClients = tester.widget<StatCard>(
      find.ancestor(of: find.text('담당 고객'), matching: find.byType(StatCard)),
    );
    expect(myClients.value, '1');
    expect(find.text('대시보드를 불러오지 못했어요'), findsNothing);
  });

  testWidgets('the KPI row reports the seeded numbers', (tester) async {
    await openDashboard(tester);

    expect(find.text('담당 고객'), findsOneWidget);
    // '메시지' 는 사이드바 내비게이션 항목명과도 겹친다 — KPI 카드 안에서만 찾는다.
    expect(
      find.descendant(of: find.byType(StatCard), matching: find.text('메시지')),
      findsOneWidget,
    );
    expect(find.text('주의 고객'), findsOneWidget);
    expect(find.text('이탈 위험'), findsOneWidget);

    // 13 of the 15 seeded clients are active; 박성호 and 문가영 are the
    // two 휴면 fixtures. 답장 대기는 **회원이 마지막으로 말한** 스레드다 —
    // 시드에서는 넷(오세라 · 배준혁 · 문가영 · 노태강)이 그렇다.
    expect(find.text('휴면 2명'), findsOneWidget);
    expect(find.text('고객 4명 대기 중'), findsOneWidget);
  });

  testWidgets('주의 고객 counts health signals, not the reply backlog', (
    tester,
  ) async {
    // 로스터를 이 테스트가 직접 만든다(#907). 데모 시드는 주간 이행률을 **오늘
    // 요일까지만** 채우므로(`_upToToday`), 기록이 있는 날의 평균으로 판정하는
    // 이행률 경고가 요일마다 붙었다 떨어졌다 한다 — 시드에 기대면 이 숫자가
    // 수요일에 하나 늘고 화요일에 하나 줄어, 어느 요일에 CI 가 도느냐로
    // 통과·실패가 갈렸다.
    await openDashboard(tester, extraOverrides: attentionRosterOverrides());

    // 답장을 기다리는 스레드가 둘이지만 주의는 건강 신호만 센다 — 나트륨 5 ·
    // 당류 1 · 이행률 2 로 여덟이다. 답장 대기는 목록에는 남되 주의가 아니다.
    // 둘이 다시 합쳐지면 이 카드가 더 큰 수를 말하며 뜻을 잃는다.
    final attention = tester.widget<StatCard>(
      find.ancestor(of: find.text('주의 고객'), matching: find.byType(StatCard)),
    );
    expect(attention.value, '8');
    expect(find.text('식단·이행률 확인'), findsOneWidget);
  });

  testWidgets('a KPI deep-links into the pre-filtered roster', (tester) async {
    await openDashboard(tester);

    await tester.tap(
      find.descendant(of: find.byType(StatCard), matching: find.text('메시지')),
    );
    await settle(tester);
    // The number and the list it opens have to be the same claim.
    expect(currentLocation(tester), contains('f=unread'));
  });

  testWidgets('오늘의 일정 lists today’s sessions and their status', (tester) async {
    await openDashboard(tester);

    expect(find.text('오늘의 일정'), findsOneWidget);
    // #1012 스케줄 탭과 같은 알약 두 장으로 바뀌어, 종류는 더 이상 이름과
    // 한 Text 로 합쳐지지 않는다 — 이름·종류·상태를 각각 확인한다.
    expect(find.text('김민수 남성 · 35세'), findsWidgets);
    expect(find.text('1:1 PT'), findsWidgets);
    expect(find.text('완료'), findsWidgets);
    // Gaps are shown but muted — a free hour is information.
    expect(find.text('빈 시간'), findsWidgets);
  });

  testWidgets(
    '고객 피드백 확인 카테고리는 건강 신호가 있는 고객만 보여주고 그 섹션으로 연결한다',
    (tester) async {
      await openDashboard(tester, extraOverrides: attentionRosterOverrides());
      await openTodoCategory(tester, 'feedback');

      // 건강 신호 여덟(나트륨 5 · 당류 1 · 이행률 2) 전부가 미션이 된다.
      // 답장 대기 둘은 건강 신호가 아니라서 이 카테고리에 없다(#907).
      expect(find.text('나트륨 초과'), findsNWidgets(5));
      expect(find.text('답장 대기'), findsNothing);

      await tester.tap(find.text('나트륨 초과').first);
      await settle(tester);
      expect(currentLocation(tester), contains('/diet'));
    },
  );

  testWidgets('AI 진단 spells out the three activity-feedback signals', (
    tester,
  ) async {
    await openDashboard(tester);

    expect(find.text('AI 진단'), findsOneWidget);
    expect(find.text('이행률 저조·이탈 위험 감지'), findsOneWidget);
    expect(find.text('7일 이상 활동 저조'), findsOneWidget);
    expect(find.text('식단 피드백 미완료'), findsOneWidget);
    expect(find.textContaining('난이도를 낮추고'), findsOneWidget);
  });

  testWidgets('AI 루틴 만들기 opens the coaching workspace', (tester) async {
    await openDashboard(tester);

    final button = find.text('AI 루틴 만들기').first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await settle(tester);
    expect(currentLocation(tester), AppRoutes.coaching);
  });

  testWidgets('the dashboard renders derived tasks without fake completion', (
    tester,
  ) async {
    await openDashboard(tester);

    expect(find.text('오늘 할 일'), findsOneWidget);
    expect(find.textContaining('확인 필요'), findsWidgets);
    expect(find.textContaining('/ 5 완료'), findsNothing);
  });

  testWidgets('wide dashboard follows the 4-KPI + 2-column body layout', (
    tester,
  ) async {
    await openDashboard(tester);

    expect(find.byType(StatCard), findsNWidgets(4));
    final actionRow = tester.widget<Row>(
      find.byKey(const ValueKey<String>('dashboard-action-row')),
    );
    expect(actionRow.children.whereType<Expanded>(), hasLength(2));
    expect(find.text('AI 진단'), findsOneWidget);
  });

  testWidgets(
    '카테고리는 각자의 대상 고객만 미션으로 세고, X 로 그리드로 돌아간다',
    (tester) async {
      final feedbackClient = makeClient(
        id: 'feedback-client',
        name: '식단 고객',
        sodiumMg: 2500,
      );
      final programClient = makeClient(
        id: 'program-client',
        name: '운동 고객',
        lastRoutine: '-',
      );
      await openDashboard(
        tester,
        extraOverrides: <Override>[
          clientsProvider.overrideWith(
            (ref) => Stream<List<TrainerClient>>.value(<TrainerClient>[
              feedbackClient,
              programClient,
            ]),
          ),
          unreadCountsProvider.overrideWith(
            (ref) => Stream<Map<String, int>>.value(const <String, int>{}),
          ),
        ],
      );

      await openTodoCategory(tester, 'feedback');
      expect(
        find.descendant(
          of: findMissionRow('feedback'),
          matching: find.textContaining('식단 고객'),
        ),
        findsOneWidget,
      );
      // 프로그램 미등록 고객은 이 카테고리에 없다.
      expect(find.textContaining('운동 고객'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('dashboard-todo-back')),
      );
      await tester.pump();

      await openTodoCategory(tester, 'program');
      expect(
        find.descendant(
          of: findMissionRow('program'),
          matching: find.textContaining('운동 고객'),
        ),
        findsOneWidget,
      );
    },
  );

  for (final scenario in <({String category, String prefix, String route})>[
    (category: 'feedback', prefix: 'feedback-sodiumOver', route: '/diet'),
    (category: 'program', prefix: 'program', route: '/coaching'),
    (category: 'report', prefix: 'report', route: '/reports'),
  ]) {
    testWidgets(
      '${scenario.category} 카테고리 미션을 누르면 해당 화면으로 이동한다',
      (tester) async {
        final client = makeClient(
          id: 'nav-client',
          name: '이동 고객',
          sodiumMg: 2500,
          lastRoutine: '-',
        );
        await openDashboard(
          tester,
          extraOverrides: <Override>[
            clientsProvider.overrideWith(
              (ref) => Stream<List<TrainerClient>>.value(<TrainerClient>[
                client,
              ]),
            ),
            unreadCountsProvider.overrideWith(
              (ref) => Stream<Map<String, int>>.value(const <String, int>{}),
            ),
          ],
        );

        await openTodoCategory(tester, scenario.category);
        final mission = findMissionRow(scenario.prefix);
        await tester.ensureVisible(mission);
        await tester.tap(mission);
        await settle(tester);

        expect(currentLocation(tester), contains(scenario.route));
      },
    );
  }

  testWidgets('상담 요청 확인 카테고리는 상담 인박스로 이동한다', (tester) async {
    await openDashboard(tester);

    await openTodoCategory(tester, 'consultation');
    final mission = findMissionRow('consultation');
    await tester.ensureVisible(mission);
    await tester.tap(mission);
    await settle(tester);

    expect(currentLocation(tester), AppRoutes.consultations);
  });

  group('AttentionCard.sectionFor', () {
    test('each alert opens the sub-tab that actually addresses it', () {
      // The row is a shortcut to the fix, not just to the client.
      expect(AttentionCard.sectionFor(ClientAlert.unanswered), 'chat');
      expect(AttentionCard.sectionFor(ClientAlert.sodiumOver), 'diet');
      expect(AttentionCard.sectionFor(ClientAlert.lowCompletion), 'workout');
    });

    test('every alert has a destination', () {
      for (final alert in ClientAlert.values) {
        expect(
          AppRoutes.clientSections,
          contains(AttentionCard.sectionFor(alert)),
          reason: '${alert.label}의 이동 대상이 없는 섹션이에요',
        );
      }
    });
  });
}
