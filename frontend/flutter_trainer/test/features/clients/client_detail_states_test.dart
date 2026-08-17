import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('an unknown client id shows a safe not-found state', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('no-such-client'),
    );

    expect(find.text('고객을 찾을 수 없어요'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('고객 목록으로'));
    await settle(tester);
    expect(find.text('고객 관리'), findsWidgets);
  });

  testWidgets('a provider error offers retry', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      extraOverrides: <Override>[
        clientsProvider.overrideWith(
          (ref) => Stream<List<TrainerClient>>.error(StateError('db down')),
        ),
      ],
    );
    await goTo(tester, AppRoutes.clientDetail('seed-client-1'));

    expect(find.text('고객 정보를 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the alert remains visible above the detail tabs', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-3', section: 'diet'),
    );

    expect(find.text('답장 대기'), findsOneWidget);
    final scroll = find
        .descendant(
          of: find.byKey(const ValueKey<String>('diet-seed-client-3')),
          matching: find.byType(ListView),
        )
        .first;
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pump();
    expect(find.text('답장 대기'), findsOneWidget);
  });

  testWidgets('diet and workout are separated into tabs', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-1'),
    );

    expect(
      find.byKey(const ValueKey<String>('client-detail-sub-tabs')),
      findsOneWidget,
    );
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(find.text('배정된 루틴'), findsNothing);

    await tester.tap(find.text('운동'));
    await settle(tester);

    expect(find.text('배정된 루틴'), findsOneWidget);
    expect(find.text('오늘 영양 요약'), findsNothing);
    final context = tester.element(find.byType(Navigator).first);
    expect(
      GoRouter.of(context).routeInformationProvider.value.uri.path,
      '/clients/seed-client-1/workout',
    );
  });

  testWidgets('workout deep-link opens only the workout tab', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
    );

    expect(find.text('배정된 루틴'), findsOneWidget);
    expect(find.text('오늘 영양 요약'), findsNothing);
  });

  test('legacy chat section safely resolves to the diet tab', () {
    final view = ClientDetailView(
      clientId: 'seed-client-1',
      section: 'chat',
      onSectionChange: (_) {},
    );

    expect(view.resolvedSection, AppRoutes.defaultClientSection);
  });

  testWidgets('빠른 동작이 이 회원의 메시지·프로그램까지 잇는다 (#823)', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-3'),
    );

    // 식단·운동을 읽다가 그 자리에서 이어지는 동작들. 예전에는 이 줄이
    // 신체·목표와 메모 둘뿐이라, 말을 걸려면 메시지 탭에서 같은 사람을 다시
    // 찾아야 했다(#823).
    expect(find.text('메시지'), findsOneWidget);
    expect(find.text('프로그램'), findsOneWidget);
    expect(find.text('고객 신체·목표 관리'), findsOneWidget);
    expect(find.text('메모'), findsOneWidget);
    // 일정 등록은 스케줄 라우트에 고객을 실을 자리가 없어 아직 넣지 않는다.
    expect(find.text('일정 등록'), findsNothing);
    expect(find.text('주간 리포트'), findsNothing);

    final actions = find.byKey(
      const ValueKey<String>('client-detail-quick-actions'),
    );
    expect(actions, findsOneWidget);
    // 메모가 줄의 오른쪽 끝을 지킨다 — 새 버튼은 왼쪽에 붙어 이 정렬을 깨지
    // 않는다(#729).
    expect(
      tester.getRect(find.widgetWithText(ActionButton, '메모')).right,
      closeTo(tester.getRect(actions).right, 0.1),
    );
  });

  testWidgets('빠른 동작이 지금 보고 있는 회원을 물고 간다 (#823)', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-3'),
    );
    final router = GoRouter.of(tester.element(find.byType(ClientDetailView)));
    String location() =>
        router.routerDelegate.currentConfiguration.uri.toString();

    await tester.tap(
      find.byKey(const ValueKey<String>('client-detail-open-program')),
    );
    await tester.pumpAndSettle();
    expect(location(), contains('/coaching'));
    expect(location(), contains('client=seed-client-3'));
  });
}
