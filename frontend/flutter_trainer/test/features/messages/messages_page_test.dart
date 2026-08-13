import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
