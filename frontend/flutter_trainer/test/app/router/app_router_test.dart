import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/app_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/app/shell/nav_destinations.dart';
import 'package:oncare_trainer/features/auth/domain/entities/session_state.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_en.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_ko.dart';

import '../../helpers/pump_app.dart';

/// 라벨 기대값은 로케일을 명시해 읽는다 — 기본 로케일이 바뀌어도 의도가 남는다.
final AppLocalizationsKo _ko = AppLocalizationsKo();
final AppLocalizationsEn _en = AppLocalizationsEn();

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

    test('in-app users are bounced off sign-in to the 대시보드', () {
      expect(
        sessionRedirect(SessionStatus.demo, AppRoutes.signIn),
        AppRoutes.dashboard,
      );
      expect(
        sessionRedirect(SessionStatus.authenticated, AppRoutes.signIn),
        AppRoutes.dashboard,
      );
    });

    test('in-app users stay put on app routes', () {
      expect(
        sessionRedirect(SessionStatus.authenticated, AppRoutes.my),
        isNull,
      );
    });
  });

  group('client detail locations', () {
    test('a bare client path is normalised onto the default section', () {
      expect(
        clientSectionRedirect('seed-client-1'),
        '/clients/seed-client-1/${AppRoutes.defaultClientSection}',
      );
    });

    test('a non-client match is left alone', () {
      expect(clientSectionRedirect(null), isNull);
    });

    test('ids are percent-encoded so a "/" in an id cannot forge a path', () {
      expect(AppRoutes.clientDetail('a/b'), '/clients/a%2Fb/diet');
    });

    test('an unknown section falls back instead of dead-ending', () {
      expect(
        AppRoutes.clientDetail('x', section: 'nope'),
        '/clients/x/${AppRoutes.defaultClientSection}',
      );
    });
  });

  group('app shell', () {
    test('AI coaching navigation label matches the page title', () {
      expect(navLabel(_ko, NavLabel.coaching), _ko.coachTitle);
      expect(navLabel(_en, NavLabel.coaching), _en.coachTitle);
    });

    test('schedule navigation label matches the page title', () {
      expect(navLabel(_ko, NavLabel.schedule), _ko.schedTitle);
      expect(navLabel(_en, NavLabel.schedule), _en.schedTitle);
    });

    testWidgets('unauthenticated boot lands on the login screen', (
      tester,
    ) async {
      await pumpTrainerApp(tester);
      expect(find.text('로그인 없이 데모 둘러보기'), findsOneWidget);
    });

    testWidgets('restored session boots into the 대시보드', (tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');

      // Auth gate redirected past sign-in into the shell.
      expect(find.text('로그인 없이 데모 둘러보기'), findsNothing);
      expect(find.text('대시보드'), findsWidgets);
    });

    testWidgets('the sidebar lists every destination on a wide viewport', (
      tester,
    ) async {
      await withWideSurface(tester, () async {
        await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');
        for (final destination in navDestinations) {
          expect(
            find.text(navLabel(_ko, destination.label)),
            findsWidgets,
            reason: '${navLabel(_ko, destination.label)} 항목이 사이드바에 없어요',
          );
        }
        // 내 정보 is reachable from the footer, not the nav list.
        expect(
          find.byKey(const ValueKey<String>('sidebar-profile')),
          findsOneWidget,
        );
      });
    });

    testWidgets('navigating switches the branch', (tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token-existing');

      await goTo(tester, AppRoutes.schedule);
      expect(find.text('스케줄'), findsWidgets);

      await goTo(tester, AppRoutes.my);
      expect(find.text('자격증 · 인증'), findsOneWidget);
    });
  });
}
