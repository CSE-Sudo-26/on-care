import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';

import '../helpers/client_factory.dart';
import '../helpers/pump_app.dart';

/// 고객 목록이 뜨는 곳마다 고객 목표가 함께 보인다. (#898)
///
/// 트레이너가 고객을 고르는 기준은 이름이 아니라 무엇을 목표로 하는
/// 사람인가다. 전에는 `고객 관리` 탭 카드에만 있었다.
void main() {
  const String goal = '혈압 관리 · 체중 감량';

  final List<TrainerClient> roster = <TrainerClient>[
    makeClient(id: 'goal-client', name: '목표고객', goal: goal),
  ];

  List<Override> rosterOverride() => <Override>[
    clientsProvider.overrideWith(
      (ref) => Stream<List<TrainerClient>>.value(roster),
    ),
  ];

  Future<void> openTab(WidgetTester tester, String at) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: at,
      extraOverrides: rosterOverride(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('메시지 스레드 목록 행에 고객 목표가 보인다', (tester) async {
    await openTab(tester, AppRoutes.messages);

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('messages-conversation-goal-client'),
        ),
        matching: find.byType(ClientGoalLabel),
      ),
      findsOneWidget,
    );
    expect(find.text(goal), findsWidgets);
  });

  testWidgets('프로그램 회원 목록 행은 마지막 루틴과 함께 목표를 보여 준다', (tester) async {
    await openTab(tester, AppRoutes.coaching);

    final Finder row = find.byKey(
      const ValueKey<String>('program-client-goal-client'),
    );
    expect(row, findsOneWidget);
    // 루틴을 보낸 적 있는 고객이다 — 전에는 이때 목표가 사라졌다.
    expect(find.descendant(of: row, matching: find.text('오늘')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(goal)), findsOneWidget);
  });

  testWidgets('리포트 고객 선택 목록 행에 고객 목표가 보인다', (tester) async {
    await openTab(tester, AppRoutes.reports);

    // 리포트 본문에는 목표를 적지 않는다 — 왼쪽 선택 목록에만 있다.
    expect(find.text(goal), findsOneWidget);
    expect(find.byType(ClientGoalLabel), findsOneWidget);
  });

  testWidgets('스케줄 상세 패널의 세션 카드에 고객 목표가 보인다', (tester) async {
    // 세션은 시드가 만든다 — 로스터만 갈아 끼우면 세션의 고객과 이어지지
    // 않아 이 카드가 이름만 그리는 분기로 빠진다.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );
    await tester.pumpAndSettle();

    // 이름은 시간표 블록과 상세 패널 양쪽에 있다 — 목표 줄은 카드에만 있다.
    expect(find.text('김민수'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('week-detail')),
        matching: find.text('혈압 관리 · 체중 감량'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('목표가 비면 빈 줄을 만들지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.messages,
      extraOverrides: <Override>[
        clientsProvider.overrideWith(
          (ref) => Stream<List<TrainerClient>>.value(<TrainerClient>[
            makeClient(id: 'no-goal', name: '목표없음', goal: '   '),
          ]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClientGoalLabel), findsWidgets);
    // 그릴 것이 없으면 Text 를 만들지 않는다.
    expect(
      find.descendant(
        of: find.byType(ClientGoalLabel),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });
}
