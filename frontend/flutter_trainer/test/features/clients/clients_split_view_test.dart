import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';

import '../../helpers/pump_app.dart';

/// Master-detail split on wide viewports (content ≥ AppLayout.splitBreakpoint).
///
/// Selection lives in the path (`/clients/<id>/<section>`), so these
/// tests assert on the URL as much as the pixels — a split panel that
/// doesn't survive a refresh is not the feature.
void main() {
  Future<void> openWide(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clients,
    );
  }

  /// The client's name in the roster card (the panel header shows it too).
  Finder card(String name) => find.text(name).first;

  testWidgets('wide viewport starts as a plain list; picking a client '
      'opens the side panel', (tester) async {
    await openWide(tester);

    // No selection yet — list only, with the empty-panel hint.
    expect(find.textContaining('왼쪽에서 고객을 선택하면'), findsOneWidget);

    await tester.tap(card('김민수'));
    await settle(tester);

    // Panel opened in place — sub-tabs visible, no push (no back button).
    expect(find.text('운동'), findsOneWidget);
    expect(find.text('채팅'), findsOneWidget);
    expect(find.text('식단'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('the close button collapses the panel back to the list', (
    tester,
  ) async {
    await openWide(tester);

    await tester.tap(card('김민수'));
    await settle(tester);
    expect(find.text('운동'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);

    expect(find.text('운동'), findsNothing);
    expect(find.textContaining('왼쪽에서 고객을 선택하면'), findsOneWidget);
  });

  testWidgets('selecting another client swaps the panel in place', (
    tester,
  ) async {
    await openWide(tester);

    await tester.tap(card('김민수'));
    await settle(tester);
    await goTo(
      tester,
      AppRoutes.clientDetail('seed-client-1', section: 'chat'),
    );
    expect(find.textContaining('AI가 김민수님의'), findsOneWidget);

    await tester.tap(card('이지수'));
    await settle(tester);

    expect(find.textContaining('AI가 이지수님의'), findsOneWidget);
    expect(find.textContaining('AI가 김민수님의'), findsNothing);
    // Still embedded — no full-screen push happened.
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('a chat draft does not leak into another client', (tester) async {
    await openWide(tester);

    await goTo(
      tester,
      AppRoutes.clientDetail('seed-client-1', section: 'chat'),
    );
    await tester.enterText(find.byType(TextField), '민수님 오늘 어땠어요?');
    await tester.pump();

    await tester.tap(card('이지수'));
    await settle(tester);

    // The composer resets with the client — no cross-client draft.
    expect(find.text('민수님 오늘 어땠어요?'), findsNothing);
  });

  testWidgets('the section stays put when switching clients', (tester) async {
    await openWide(tester);

    // Open 식단 for 김민수 (2100mg — appears on the summary tile and as
    // the last sodium-trend bar label, so match ≥1)…
    await goTo(
      tester,
      AppRoutes.clientDetail('seed-client-1', section: 'diet'),
    );
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(find.text('2100'), findsWidgets);

    // …switch to 박성호: same sub-tab, his data (2400mg).
    await tester.tap(card('박성호'));
    await settle(tester);
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(find.text('2400'), findsWidgets);
  });

  testWidgets('the list is ordered by priority: sodium-over first, then '
      'recent chat', (tester) async {
    await openWide(tester);

    // 김민수(2100mg)·박성호(2400mg) are over the 2000mg target and rank
    // above 이지수(1800mg); 김민수 has the most recent chat of the two.
    final kim = tester.getTopLeft(card('김민수')).dy;
    final park = tester.getTopLeft(card('박성호')).dy;
    final lee = tester.getTopLeft(card('이지수')).dy;
    expect(kim, lessThan(park));
    expect(park, lessThan(lee));
  });

  testWidgets('the panel location is a path that encodes the section', (
    tester,
  ) async {
    await openWide(tester);
    await tester.tap(card('김민수'));
    await settle(tester);

    final ctx = tester.element(find.text('운동'));
    final uri = GoRouterState.of(ctx).uri;
    // Path-based, not `?c=`: refresh, back/forward and shared links all
    // restore the same client AND the same sub-tab.
    expect(uri.path, '/clients/seed-client-1/diet');
  });

  testWidgets('the detail header fits the narrowest split panel', (
    tester,
  ) async {
    // Exactly at the breakpoint the panel is its thinnest (viewport −
    // the 340px roster − the divider ≈ 559px), and the header is dense:
    // name + 활성 + 채팅 button + close on one row, then three metric
    // tiles, then two actions. Flutter throws on a RenderFlex overflow,
    // so rendering it here is the assertion.
    tester.view.physicalSize = const Size(AppLayout.splitBreakpoint, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      // 김민수 is over on sodium, so the alert row renders too.
      at: AppRoutes.clientDetail('seed-client-1', section: 'diet'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('나트륨 초과'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('client-chat-button')),
      findsOneWidget,
    );
  });

  testWidgets('a percent-encoded id round-trips through the path', (
    tester,
  ) async {
    await openWide(tester);
    // A backend member id is not guaranteed URL-safe; the location must
    // survive one that isn't.
    expect(AppRoutes.clientDetail('a b/c'), '/clients/a%20b%2Fc/diet');
  });
}
