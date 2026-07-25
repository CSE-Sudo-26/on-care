import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';

import '../../helpers/pump_app.dart';

/// Master-detail split on wide viewports (≥ AppLayout.splitBreakpoint).
void main() {
  Future<void> openWide(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(tester, token: 'demo-trainer-token');
  }

  testWidgets('wide viewport starts as a plain list; picking a client '
      'opens the side panel', (tester) async {
    await openWide(tester);

    // No selection yet — list only, no detail panel.
    expect(find.text('고객 관리'), findsOneWidget);
    expect(find.text('채팅'), findsNothing);

    await tester.tap(find.text('김민수'));
    await settle(tester);

    // Panel opened in place — sub-tabs visible, no push (no back button).
    expect(find.text('채팅'), findsOneWidget);
    expect(find.text('식단'), findsOneWidget);
    expect(find.textContaining('AI가 김민수님의'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('the close button collapses the panel back to the list', (
    tester,
  ) async {
    await openWide(tester);

    await tester.tap(find.text('김민수'));
    await settle(tester);
    expect(find.text('채팅'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);

    expect(find.text('채팅'), findsNothing);
    expect(find.text('고객 관리'), findsOneWidget);
  });

  testWidgets('selecting another client swaps the panel in place', (
    tester,
  ) async {
    await openWide(tester);

    await tester.tap(find.text('김민수'));
    await settle(tester);
    await tester.tap(find.text('이지수'));
    await settle(tester);

    expect(find.textContaining('AI가 이지수님의'), findsOneWidget);
    expect(find.textContaining('AI가 김민수님의'), findsNothing);
    // Still embedded — no full-screen push happened.
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('a chat draft does not leak into another client', (tester) async {
    await openWide(tester);

    await tester.tap(find.text('김민수'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '민수님 오늘 어땠어요?');
    await tester.pump();

    await tester.tap(find.text('이지수'));
    await settle(tester);

    // The composer resets with the client — no cross-client draft.
    expect(find.text('민수님 오늘 어땠어요?'), findsNothing);
  });

  testWidgets('sub-tab selection survives switching clients', (tester) async {
    await openWide(tester);

    await tester.tap(find.text('김민수'));
    await settle(tester);

    // Open 식단 for 김민수 (2100mg — appears on the summary tile and as
    // the last sodium-trend bar label, so match ≥1)…
    await tester.tap(find.text('식단'));
    await settle(tester);
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(find.text('2100'), findsWidgets);

    // …switch to 박성호: same sub-tab, his data (2400mg).
    await tester.tap(find.text('박성호'));
    await settle(tester);
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(find.text('2400'), findsWidgets);
  });

  testWidgets('the list is ordered by priority: sodium-over first, then '
      'recent chat', (tester) async {
    await openWide(tester);

    // 김민수(2100mg)·박성호(2400mg) are over the 2000mg target and rank
    // above 이지수(1800mg); 김민수 has the most recent chat of the two.
    final kim = tester.getTopLeft(find.text('김민수')).dy;
    final park = tester.getTopLeft(find.text('박성호')).dy;
    final lee = tester.getTopLeft(find.text('이지수')).dy;
    expect(kim, lessThan(park));
    expect(park, lessThan(lee));
  });

  testWidgets('the panel location percent-encodes the client id', (
    tester,
  ) async {
    await openWide(tester);
    await tester.tap(find.text('김민수'));
    await settle(tester);

    // Built via Uri(), so the id lands in a real query parameter that
    // round-trips (a hand-concatenated string would break on ?/&/유니코드).
    final ctx = tester.element(find.text('고객 관리'));
    final uri = GoRouterState.of(ctx).uri;
    expect(uri.path, AppRoutes.clients);
    expect(uri.queryParameters['c'], 'seed-client-1');
  });
}
