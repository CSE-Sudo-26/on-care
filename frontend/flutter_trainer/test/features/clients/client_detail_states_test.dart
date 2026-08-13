import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

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
    expect(find.text('회원 관리'), findsWidgets);
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

  testWidgets('the alert remains visible above the unified detail scroll', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-3', section: 'diet'),
    );

    expect(find.text('답장 대기'), findsOneWidget);
    final scroll = find.byKey(
      const ValueKey<String>('client-detail-scroll-seed-client-3'),
    );
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pump();
    expect(find.text('답장 대기'), findsOneWidget);
  });

  testWidgets('diet and workout share one 360-degree detail scroll', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-1'),
    );

    final scroll = find.byKey(
      const ValueKey<String>('client-detail-scroll-seed-client-1'),
    );
    expect(scroll, findsOneWidget);
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('client-detail-sub-tabs')),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('배정된 루틴'),
      250,
      scrollable: find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('배정된 루틴'), findsOneWidget);
  });

  testWidgets('workout deep-link keeps workout evidence first', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
    );

    final workoutTop = tester.getTopLeft(find.text('배정된 루틴')).dy;
    final dietTop = tester.getTopLeft(find.text('오늘 영양 요약')).dy;
    expect(workoutTop, lessThan(dietTop));
  });

  testWidgets('message action opens the standalone messages workspace', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-3'),
    );

    await tester.tap(find.text('메시지'));
    await settle(tester);
    final context = tester.element(find.byType(Navigator).first);
    expect(
      GoRouter.of(context).routeInformationProvider.value.uri.toString(),
      AppRoutes.messagesFor('seed-client-3'),
    );
  });
}
