import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

/// Loading / error / not-found handling for the client detail body.
void main() {
  testWidgets('an unknown client id shows the not-found message instead '
      'of a nameless chat', (tester) async {
    await pumpTrainerApp(tester, token: 'demo-trainer-token');

    // Deep-link to a client that doesn't exist (stale link).
    final ctx = tester.element(find.text('고객 관리'));
    GoRouter.of(ctx).push(AppRoutes.clientDetail('no-such-client'));
    await settle(tester);

    expect(find.text('고객을 찾을 수 없어요'), findsOneWidget);
    // No chat composer / sub-tabs for a client that doesn't exist.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('채팅'), findsNothing);

    // The escape hatch returns to the client list.
    await tester.tap(find.text('고객 목록으로'));
    await settle(tester);
    expect(find.text('고객 관리'), findsOneWidget);
  });

  testWidgets('a provider error shows the failure message with 다시 시도', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      extraOverrides: <Override>[
        clientsProvider.overrideWith(
          (ref) => Stream<List<TrainerClient>>.error(StateError('db down')),
        ),
      ],
    );

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push(AppRoutes.clientDetail('seed-client-1'));
    await settle(tester);

    expect(find.text('고객 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    // Retry re-subscribes the stream — tapping must not throw.
    await tester.tap(find.text('다시 시도'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  // Both activation keys a focusable button must honour (review PR 216).
  for (final activation in <(String, LogicalKeyboardKey)>[
    ('Enter', LogicalKeyboardKey.enter),
    ('Space', LogicalKeyboardKey.space),
  ]) {
    final (keyName, key) = activation;
    testWidgets('sub-tabs are keyboard-reachable and activate on $keyName', (
      tester,
    ) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      await tester.tap(find.text('김민수'));
      await settle(tester);
      expect(find.text('채팅'), findsOneWidget);
      // Start on the 채팅 sub-tab (default), not the 식단 view.
      expect(find.text('오늘 영양 요약'), findsNothing);

      // Whether the 식단 sub-tab currently holds keyboard focus.
      bool sikdanFocused() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return false;
        return find
            .descendant(
              of: find.byElementPredicate((e) => e == ctx),
              matching: find.text('식단'),
            )
            .evaluate()
            .isNotEmpty;
      }

      // Tab through the focus order until the 식단 sub-tab is focused —
      // proves it participates in keyboard traversal (was unreachable as
      // a bare GestureDetector).
      var reached = false;
      for (var i = 0; i < 12 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached = sikdanFocused();
      }
      expect(reached, isTrue, reason: '키보드 Tab으로 식단 탭에 도달할 수 있어야 함');

      // The activation key switches the tab — no pointer involved.
      await tester.sendKeyEvent(key);
      await settle(tester);
      expect(find.text('오늘 영양 요약'), findsOneWidget);
    });
  }

  testWidgets('the selected sub-tab exposes its state on the focus node', (
    tester,
  ) async {
    await pumpTrainerApp(tester, token: 'demo-trainer-token');
    await tester.tap(find.text('김민수'));
    await settle(tester);

    // MergeSemantics folds the selected/button flags into the node the
    // reader actually hits, so one node carries label + state.
    final flags = tester.getSemantics(find.text('채팅')).flagsCollection;
    expect(
      flags.isSelected,
      Tristate.isTrue,
      reason: '기본 선택된 채팅 탭이 selected 로 안내돼야 함',
    );
    expect(flags.isButton, isTrue);
  });
}
