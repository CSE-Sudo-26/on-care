import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('TrainerSignInPage', () {
    testWidgets('shows a validation snackbar when fields are empty', (
      tester,
    ) async {
      await pumpTrainerApp(tester);

      await tester.tap(find.widgetWithText(InkWell, '로그인'));
      await tester.pump(); // let the snackbar appear

      expect(find.text('이메일과 비밀번호를 입력해 주세요'), findsOneWidget);
    });

    testWidgets('demo bypass enters demo mode and leaves the login screen', (
      tester,
    ) async {
      final container = await pumpTrainerApp(tester);

      await tester.tap(find.text('로그인 없이 데모 둘러보기'));
      await settle(tester);

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.demo,
      );
      // Left the login screen (no more login button / demo link).
      expect(find.text('로그인 없이 데모 둘러보기'), findsNothing);
    });

    testWidgets('login with credentials authenticates and navigates away', (
      tester,
    ) async {
      final container = await pumpTrainerApp(tester);

      await tester.enterText(
        find.byType(TextField).at(0),
        'trainer@oncare.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'pw');
      await tester.tap(find.widgetWithText(InkWell, '로그인'));
      await settle(tester);

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.authenticated,
      );
      expect(find.text('로그인 없이 데모 둘러보기'), findsNothing);
    });
  });
}
