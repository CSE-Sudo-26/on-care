import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart'
    show clientSectionLabels;
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

/// Loading / error / not-found handling for the client detail body.
void main() {
  test('every sub-tab label has a section behind it', () {
    // _SubTabs iterates the labels and indexes clientTabSections with
    // the same i, so a length mismatch is a RangeError on tap (extra
    // label) or a tab with no way to reach it (extra section). They are
    // edited in different files, so the pairing needs a guard.
    expect(clientSectionLabels.length, AppRoutes.clientTabSections.length);
    // Every tabbed section must also be an addressable route, and the
    // chat must NOT be a tab — it's the header's message button.
    for (final tab in AppRoutes.clientTabSections) {
      expect(AppRoutes.clientSections, contains(tab));
    }
    expect(
      AppRoutes.clientTabSections,
      isNot(contains(AppRoutes.clientChatSection)),
    );
    expect(AppRoutes.clientSections, contains(AppRoutes.clientChatSection));
    expect(
      AppRoutes.clientTabSections,
      contains(AppRoutes.defaultClientSection),
      reason: '기본 섹션이 탭에 없으면 진입 시 선택된 탭이 없다',
    );
  });

  testWidgets('an unknown client id shows the not-found message instead '
      'of a nameless chat', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      // Deep-link to a client that doesn't exist (stale link).
      at: AppRoutes.clientDetail('no-such-client'),
    );

    expect(find.text('고객을 찾을 수 없어요'), findsOneWidget);
    // No chat composer / sub-tabs for a client that doesn't exist.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('채팅'), findsNothing);

    // The escape hatch returns to the client list.
    await tester.tap(find.text('고객 목록으로'));
    await settle(tester);
    expect(find.text('고객'), findsWidgets);
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

    await goTo(tester, AppRoutes.clientDetail('seed-client-1'));

    expect(find.text('고객 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    // Retry re-subscribes the stream — tapping must not throw.
    await tester.tap(find.text('다시 시도'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header shows the 답장 대기 reason the dashboard flagged', (
    tester,
  ) async {
    // The alert strip used to call alertsFor() without the unread count,
    // so this badge could never appear — a client the dashboard flagged
    // in red lost its reason the moment you opened them (CodeRabbit
    // #377). It now lives in the header, so it holds on every sub-tab.
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      // 박성호 is the one still waiting — 김민수's thread is seeded
      // already answered. Any section but the chat: opening the thread
      // marks it read, which legitimately clears the badge.
      at: AppRoutes.clientDetail('seed-client-3', section: 'diet'),
    );

    expect(find.text('답장 대기'), findsOneWidget);

    // Still there after switching tabs — the point of moving it out of
    // the 개요 tab it used to live in is that it holds everywhere.
    await tester.tap(find.text('운동'));
    await settle(tester);
    expect(find.text('답장 대기'), findsOneWidget);
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
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1'),
      );
      // Starts on 식단 (the default), so 운동's content is not up yet.
      expect(find.text('오늘 영양 요약'), findsOneWidget);
      expect(find.text('배정된 루틴'), findsNothing);

      // Whether the 운동 sub-tab currently holds keyboard focus.
      bool undongFocused() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return false;
        return find
            .descendant(
              of: find.byElementPredicate((e) => e == ctx),
              matching: find.text('운동'),
            )
            .evaluate()
            .isNotEmpty;
      }

      // Tab through the focus order until the 운동 sub-tab is focused —
      // proves it participates in keyboard traversal (was unreachable as
      // a bare GestureDetector).
      var reached = false;
      for (var i = 0; i < 12 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached = undongFocused();
      }
      expect(reached, isTrue, reason: '키보드 Tab으로 운동 탭에 도달할 수 있어야 함');

      // The activation key switches the tab — no pointer involved.
      await tester.sendKeyEvent(key);
      await settle(tester);
      expect(find.text('배정된 루틴'), findsOneWidget);
    });
  }

  testWidgets('the selected sub-tab exposes its state on the focus node', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-1'),
    );

    // MergeSemantics folds the selected/button flags into the node the
    // reader actually hits, so one node carries label + state.
    final flags = tester.getSemantics(find.text('식단')).flagsCollection;
    expect(
      flags.isSelected,
      Tristate.isTrue,
      reason: '기본 선택된 식단 탭이 selected 로 안내돼야 함',
    );
    expect(flags.isButton, isTrue);
  });

  testWidgets('the chat sits in the sub-tab row and never leaves it empty', (
    tester,
  ) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clientDetail('seed-client-1'),
    );

    // 채팅 is not a content tab — it is the row's trailing segment.
    expect(find.text('채팅'), findsOneWidget);
    expect(clientSectionLabels, isNot(contains('채팅')));

    final button = find.byKey(const ValueKey<String>('client-chat-button'));
    expect(button, findsOneWidget);

    // Same row as the content tabs: one strip answers "which section am I
    // in", instead of the header owning half that answer.
    expect(
      tester.getCenter(button).dy,
      tester.getCenter(find.text('식단')).dy,
      reason: '채팅 세그먼트는 식단·운동과 같은 줄에 있어야 함',
    );

    // Not selected while a content tab is open.
    expect(
      tester.getSemantics(button).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    await tester.tap(button);
    await settle(tester);

    // The thread opened and the chat segment took the selection, so the
    // strip still shows where you are — it used to go blank here.
    expect(find.byType(TextField), findsOneWidget); // the composer
    expect(
      tester.getSemantics(button).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    for (final String label in clientSectionLabels) {
      expect(
        tester.getSemantics(find.text(label)).flagsCollection.isSelected,
        Tristate.isFalse,
        reason: '채팅 중에는 콘텐츠 탭이 선택돼 있으면 안 됨',
      );
    }
  });

  testWidgets('the message button carries the unread count', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      // 박성호 has one message waiting.
      at: AppRoutes.clientDetail('seed-client-3', section: 'diet'),
    );

    final button = find.byKey(const ValueKey<String>('client-chat-button'));
    expect(
      find.descendant(of: button, matching: find.text('1')),
      findsOneWidget,
    );
    // One node, one sentence: the visible '채팅' and the bare count must
    // not be announced again after the label.
    expect(tester.getSemantics(button).label, '박성호님과 채팅, 안 읽은 메시지 1개');
  });
}
