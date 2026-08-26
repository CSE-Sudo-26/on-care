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

    testWidgets('데모 진입은 기본 빌드에서 뜨지 않는다', (tester) async {
      // 로그인 없이 콘솔로 들어가는 경로를 화면에서 내렸다. 코드는 남아 있고
      // 노출만 SHOW_DEMO_ENTRY 로 막았다. (#1526)
      await pumpTrainerApp(tester);

      expect(find.text('로그인 없이 데모 둘러보기'), findsNothing);
      // 로그인 화면 자체는 그대로다 — 감춘 것이 이 버튼뿐임을 함께 못 박는다.
      expect(find.widgetWithText(InkWell, '로그인'), findsOneWidget);
    });

    testWidgets('demo bypass enters demo mode and leaves the login screen', (
      tester,
    ) async {
      // 진입 버튼은 기본 빌드에서 감춰 뒀다. 되돌릴 수 있게 남긴 경로이므로
      // 플래그를 켜고 그 경로가 계속 도는지 확인한다. (#1526)
      final container = await pumpTrainerApp(tester, demoEntry: true);

      // The demo link sits below the fold on the (taller, redesigned)
      // login screen — scroll it into view before tapping.
      await tester.ensureVisible(find.text('로그인 없이 데모 둘러보기'));
      await tester.pump();
      await tester.tap(find.text('로그인 없이 데모 둘러보기'));
      await settle(tester);

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.demo,
      );
      // Left the login screen (no more login button / demo link).
      expect(find.text('로그인 없이 데모 둘러보기'), findsNothing);
      expect(find.text('계정 만들기'), findsNothing);
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
      expect(find.text('계정 만들기'), findsNothing);
    });
  });
}
