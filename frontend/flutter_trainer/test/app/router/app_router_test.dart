import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/app_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('sessionRedirect', () {
    test('signed-out is forced onto sign-in from any app route', () {
      expect(
        sessionRedirect(SessionStatus.signedOut, AppRoutes.clients),
        AppRoutes.signIn,
      );
      expect(
        sessionRedirect(SessionStatus.unknown, AppRoutes.schedule),
        AppRoutes.signIn,
      );
    });

    test('signed-out stays on sign-in (no redirect loop)', () {
      expect(
        sessionRedirect(SessionStatus.signedOut, AppRoutes.signIn),
        isNull,
      );
    });

    test('in-app users are bounced off sign-in to the 고객 tab', () {
      expect(
        sessionRedirect(SessionStatus.demo, AppRoutes.signIn),
        AppRoutes.clients,
      );
      expect(
        sessionRedirect(SessionStatus.authenticated, AppRoutes.signIn),
        AppRoutes.clients,
      );
    });

    test('in-app users stay put on app routes', () {
      expect(
        sessionRedirect(SessionStatus.authenticated, AppRoutes.my),
        isNull,
      );
    });
  });

  group('app shell', () {
    testWidgets('unauthenticated boot lands on the login screen', (
      tester,
    ) async {
      await pumpTrainerApp(tester);
      expect(find.text('로그인 없이 데모 둘러보기'), findsOneWidget);
    });

    testWidgets('restored session boots into the shell (고객 tab)', (
      tester,
    ) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');

      // Auth gate redirected past sign-in into the shell.
      expect(find.text('로그인 없이 데모 둘러보기'), findsNothing);
      expect(find.text('고객 관리'), findsOneWidget);
      // Bottom nav shows all four tabs.
      expect(find.text('고객'), findsOneWidget);
      expect(find.text('스케줄'), findsOneWidget);
      expect(find.text('AI루틴'), findsOneWidget);
      expect(find.text('MY'), findsOneWidget);
    });

    testWidgets('tapping a tab switches the branch', (tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');

      await tester.tap(find.text('스케줄'));
      await settle(tester);
      expect(find.textContaining('온케어짐 신촌점'), findsOneWidget);

      await tester.tap(find.text('MY'));
      await settle(tester);
      expect(find.text('자격증 · 인증'), findsOneWidget);
    });
  });
}
