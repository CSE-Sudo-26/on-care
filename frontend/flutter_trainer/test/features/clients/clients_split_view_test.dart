import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/presentation/pages/clients_page.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';

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

  /// Brings a roster card into view before tapping it. The roster is
  /// fifteen clients and lazily built, so anyone ranked below the fold
  /// simply does not exist yet.
  ///
  /// The scrollable is located through a card rather than by index — the
  /// sidebar and the open detail panel are scrollables too, and which
  /// one comes first in the tree is not this test's business.
  Future<void> scrollToCard(WidgetTester tester, String name) async {
    // Check the raw finder, not `card()` — `.first` throws rather than
    // reporting empty when nothing matched.
    final candidates = find.text(name);
    if (candidates.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(name),
        160,
        scrollable: find
            .ancestor(
              of: find.byType(ClientCard).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }

    // A lazily built card can already exist just beyond the viewport. In
    // that case scrollUntilVisible is skipped, but tapping still misses it.
    await tester.ensureVisible(candidates.first);
    await tester.pumpAndSettle();
  }

  testWidgets('wide viewport starts as a plain list; picking a client '
      'opens the side panel', (tester) async {
    await openWide(tester);

    // No selection yet — list only, with the empty-panel hint.
    expect(find.textContaining('왼쪽에서 고객을 선택하면'), findsOneWidget);

    await tester.tap(card('김민수'));
    await settle(tester);

    // Panel opened in place with the unified detail, no push.
    expect(find.text('운동'), findsOneWidget);
    expect(find.text('메시지'), findsWidgets);
    expect(find.text('식단'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('the roster card has visible space before the detail panel', (
    tester,
  ) async {
    await openWide(tester);
    await tester.tap(card('김민수'));
    await settle(tester);

    final cardRect = tester.getRect(find.byType(ClientCard).first);
    final detailRect = tester.getRect(find.byType(ClientDetailView));

    expect(
      detailRect.left - cardRect.right,
      AppSpacing.lg,
      reason: '목록 카드의 우측 테두리와 그림자가 잘리지 않아야 한다',
    );
    expect(
      find.byKey(const ValueKey<String>('clients-master-detail-gap')),
      findsOneWidget,
    );
  });

  testWidgets('picking a client does not expose the parent roster during '
      'the route change', (tester) async {
    await openWide(tester);

    await tester.tap(card('김민수'));
    await tester.pump();
    await tester.pump();

    // The detail route is nested under `/clients`. A default Material page
    // transition leaves the parent roster exposed while the new page enters,
    // which appears as a brief roster flash. The router consumes the first
    // pump; the second is the first frame that contains the detail route.
    expect(find.byType(ClientsPage), findsOneWidget);
    expect(find.text('오늘 영양 요약'), findsOneWidget);
  });

  testWidgets('the close button collapses the panel back to the list', (
    tester,
  ) async {
    await openWide(tester);

    await tester.tap(card('김민수'));
    await settle(tester);
    expect(find.text('운동'), findsOneWidget);

    await tester.tap(find.byTooltip('패널 닫기'));
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
    expect(find.textContaining('3,428', findRichText: true), findsWidgets);

    await scrollToCard(tester, '이지수');
    await tester.tap(card('이지수'));
    await settle(tester);

    expect(find.textContaining('3,428', findRichText: true), findsNothing);
    // Still embedded — no full-screen push happened.
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('the detail scroll state does not leak into another client', (
    tester,
  ) async {
    await openWide(tester);

    await tester.tap(card('김민수'));
    await settle(tester);

    expect(
      find.byKey(const ValueKey<String>('client-detail-scroll-seed-client-1')),
      findsOneWidget,
    );

    await scrollToCard(tester, '이지수');
    await tester.tap(card('이지수'));
    await settle(tester);

    expect(
      find.byKey(const ValueKey<String>('client-detail-scroll-seed-client-2')),
      findsOneWidget,
    );
  });

  testWidgets('the section stays put when switching clients', (tester) async {
    await openWide(tester);

    // Open 식단 for 김민수 (3,428mg — appears on the summary card and as
    // the last sodium-trend bar label, so match ≥1)…
    await goTo(
      tester,
      AppRoutes.clientDetail('seed-client-1', section: 'diet'),
    );
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(find.textContaining('3,428', findRichText: true), findsWidgets);

    // …switch to 박성호: same sub-tab, his data (2,400mg).
    await tester.tap(card('박성호'));
    await settle(tester);
    expect(find.text('오늘 영양 요약'), findsOneWidget);
    expect(find.textContaining('2,400', findRichText: true), findsWidgets);
  });

  testWidgets('the list is ordered by priority: sodium-over first', (
    tester,
  ) async {
    await openWide(tester);

    // Read the rendered order rather than three clients' Y positions:
    // the roster is long enough now that not every name is built, so
    // measuring specific ones would depend on where the list happens to
    // sit. Every over-target client must precede every under-target one.
    final rendered = tester
        .widgetList<ClientCard>(find.byType(ClientCard))
        .toList();
    expect(rendered.length, greaterThan(2));
    final firstUnderTarget = rendered.indexWhere(
      (c) => !c.client.sodiumOverBudget,
    );
    if (firstUnderTarget >= 0) {
      expect(
        rendered
            .skip(firstUnderTarget)
            .every((c) => !c.client.sodiumOverBudget),
        isTrue,
        reason: '나트륨 초과 고객이 목표 이내 고객보다 아래에 오면 안 된다',
      );
    }
    // The top of the list is where the trainer looks first.
    expect(rendered.first.client.sodiumOverBudget, isTrue);
  });

  testWidgets('the panel location is a path that encodes the section', (
    tester,
  ) async {
    await openWide(tester);
    await tester.tap(card('김민수'));
    await settle(tester);

    final ctx = tester.element(find.text('식단'));
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
    expect(find.text('나트륨 초과'), findsWidgets);
    expect(find.text('메시지'), findsOneWidget);
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
