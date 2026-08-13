import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('messages route renders the two-pane conversation workspace', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
      await goTo(tester, AppRoutes.messagesFor('seed-client-1'));

      expect(find.text('대화'), findsOneWidget);
      expect(find.textContaining('읽지 않음'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('프로그램'), findsWidgets);
      expect(find.text('일정'), findsWidgets);
    });
  });

  testWidgets('client query keeps the selected member in the thread', (
    tester,
  ) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
      await goTo(tester, AppRoutes.messagesFor('seed-client-2'));

      expect(
        find.byKey(const ValueKey<String>('messages-thread-seed-client-2')),
        findsOneWidget,
      );
    });
  });

  testWidgets('new workspace labels render in English locale', (tester) async {
    await withWideSurface(tester, () async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token-existing',
        locale: const Locale('en'),
      );
      await goTo(tester, AppRoutes.messagesFor('seed-client-1'));

      expect(find.text('Messages'), findsWidgets);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.textContaining('Unread'), findsOneWidget);
      expect(find.text('Program'), findsWidgets);
      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('대화'), findsNothing);
      expect(find.text('프로그램'), findsNothing);
    });
  });

  testWidgets('mobile back keeps the active conversation filter', (
    tester,
  ) async {
    await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
    await goTo(
      tester,
      AppRoutes.messagesFor('seed-client-1', filter: 'unread'),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    final context = tester.element(find.byType(Navigator).first);
    expect(
      GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.uri.queryParameters['f'],
      'unread',
    );
  });
}
