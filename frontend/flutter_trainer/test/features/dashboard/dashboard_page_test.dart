import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/attention_card.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/widgets/stat_card.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

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

    expect(find.text('복구 고객'), findsWidgets);
    expect(find.text('대시보드를 불러오지 못했어요'), findsNothing);
  });

  testWidgets('the KPI row reports the seeded numbers', (tester) async {
    await openDashboard(tester);

    expect(find.text('오늘 예약'), findsOneWidget);
    expect(find.text('담당 고객'), findsOneWidget);
    expect(find.text('답장 필요'), findsOneWidget);
    expect(find.text('주의 고객'), findsOneWidget);

    // 13 of the 15 seeded clients are active; 박성호 and 문가영 are the
    // two 휴면 fixtures. Six threads are waiting on a reply.
    expect(find.text('휴면 2명'), findsOneWidget);
    expect(find.text('고객 6명 대기 중'), findsOneWidget);
  });

  testWidgets('주의 고객 counts health signals, not the reply backlog', (
    tester,
  ) async {
    await openDashboard(tester);

    // 답장을 기다리는 스레드가 여섯이지만 주의는 건강 신호만 센다 — 나트륨 5 ·
    // 당류 1 · 이행률 2 로 여덟이다. 답장 대기는 목록에는 남되 주의가 아니다.
    // 둘이 다시 합쳐지면 이 카드가 더 큰 수를 말하며 뜻을 잃는다.
    //
    // 류태경(벌크업)은 칼로리가 3,120kcal 로 높지만 여기 없다 — 칼로리는 신호가
    // 아니고, 그의 식단 수치는 목표 안이다(#767·#768).
    final attention = tester.widget<StatCard>(
      find.ancestor(of: find.text('주의 고객'), matching: find.byType(StatCard)),
    );
    expect(attention.value, '8');
    expect(find.text('식단·이행률 확인'), findsOneWidget);
  });

  testWidgets('a KPI deep-links into the pre-filtered roster', (tester) async {
    await openDashboard(tester);

    await tester.tap(find.text('답장 필요'));
    await settle(tester);
    // The number and the list it opens have to be the same claim.
    expect(currentLocation(tester), contains('f=unread'));
  });

  testWidgets('오늘의 일정 lists today’s sessions and their status', (tester) async {
    await openDashboard(tester);

    expect(find.text('오늘의 일정'), findsOneWidget);
    expect(find.text('김민수 남성 · 35세 · 1:1 PT'), findsWidgets);
    expect(find.text('완료'), findsWidgets);
    // Gaps are shown but muted — a free hour is information.
    expect(find.text('빈 시간'), findsWidgets);
  });

  testWidgets('주의 고객 rows carry the reason and open the section that '
      'fixes it', (tester) async {
    await openDashboard(tester);

    expect(find.text('확인 필요 고객'), findsOneWidget);
    // Ten clients carry an alert of some kind — note this list is wider
    // than the 주의 고객 count above it, which is health signals only and
    // reads 9. The card shows five, so the overflow link into the
    // filtered roster is finally reachable; with the old three-client
    // roster it could never appear.
    expect(find.text('+5명'), findsOneWidget);

    // The badge is a client's FIRST alert, and health reasons sort ahead
    // of 답장 대기, so every visible row leads with a health one.
    expect(find.text('나트륨 초과'), findsWidgets);
    expect(find.text('답장 대기'), findsNothing);

    await tester.tap(find.text('나트륨 초과').first);
    await settle(tester);
    expect(currentLocation(tester), contains('/diet'));
  });

  testWidgets(
    'the AI summary names a client and gives a specific exercise focus',
    (tester) async {
      await openDashboard(tester);

      expect(find.text('AI 코칭 요약'), findsOneWidget);
      // 머리말은 1순위 회원의 이름을 부른다. 그게 누구인지는 그날의 수치가
      // 정하므로(#767 이후 초과 폭 순) 이름을 박지 않는다 — 박아 두면 시드가
      // 조금만 움직여도 깨지고, 정작 검증하려는 건 "이름을 부른다" 는 것이다.
      expect(find.textContaining('고객을 먼저 확인하고'), findsWidgets);
      expect(find.text('오늘 운동 중심'), findsWidgets);
      expect(find.textContaining('중강도 걷기'), findsWidgets);
      expect(find.text('판단 근거'), findsWidgets);
    },
  );

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

  testWidgets('wide dashboard follows the 4-3-1 card layout', (tester) async {
    await openDashboard(tester);

    expect(find.byType(StatCard), findsNWidgets(4));
    final actionRow = tester.widget<Row>(
      find.byKey(const ValueKey<String>('dashboard-action-row')),
    );
    expect(actionRow.children.whereType<Expanded>(), hasLength(3));
    expect(find.text('AI 코칭 요약'), findsOneWidget);
  });

  testWidgets('today tasks show one item from each available action type', (
    tester,
  ) async {
    await openDashboard(tester);

    expect(
      find.byKey(const ValueKey<String>('dashboard-task-unanswered')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-task-lowCompletion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-task-sodiumOver')),
      findsOneWidget,
    );
  });

  testWidgets('today tasks prefer different clients for each action type', (
    tester,
  ) async {
    final allAlerts = makeClient(
      id: 'all-alerts',
      name: '중복 고객',
      sodiumMg: 2500,
      weekCompletion: const <int>[40, 40, 0, 0, 0, 0, 0],
    );
    final replyOnly = makeClient(id: 'reply-only', name: '답장 고객');
    final workoutOnly = makeClient(
      id: 'workout-only',
      name: '운동 고객',
      weekCompletion: const <int>[40, 40, 0, 0, 0, 0, 0],
    );
    final dietOnly = makeClient(id: 'diet-only', name: '식단 고객', sodiumMg: 2500);
    await openDashboard(
      tester,
      extraOverrides: <Override>[
        clientsProvider.overrideWith(
          (ref) => Stream<List<TrainerClient>>.value(<TrainerClient>[
            allAlerts,
            replyOnly,
            workoutOnly,
            dietOnly,
          ]),
        ),
        unreadCountsProvider.overrideWith(
          (ref) => Stream<Map<String, int>>.value(const <String, int>{
            'all-alerts': 1,
            'reply-only': 1,
          }),
        ),
      ],
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dashboard-task-unanswered')),
        matching: find.textContaining('중복 고객'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dashboard-task-lowCompletion')),
        matching: find.textContaining('운동 고객'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dashboard-task-sodiumOver')),
        matching: find.textContaining('식단 고객'),
      ),
      findsOneWidget,
    );
  });

  for (final scenario in <({String task, String route})>[
    (task: 'unanswered', route: '/messages?client='),
    (task: 'lowCompletion', route: '/workout'),
    (task: 'sodiumOver', route: '/diet'),
  ]) {
    testWidgets('today ${scenario.task} task opens its action destination', (
      tester,
    ) async {
      await openDashboard(tester);

      final task = find.byKey(
        ValueKey<String>('dashboard-task-${scenario.task}'),
      );
      await tester.ensureVisible(task);
      await tester.tap(task);
      await settle(tester);

      expect(currentLocation(tester), contains(scenario.route));
    });
  }

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
