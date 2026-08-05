import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/attention_card.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';

import '../../helpers/pump_app.dart';

/// The 대시보드 against the seeded roster.
///
/// Seed: 3 clients (김민수 2100mg and 박성호 2400mg are over the 2000mg
/// target, 이지수 1800mg is not; 이지수 is 휴면), all three have unread
/// replies (4 in total), and today has 4 booked sessions (6 slots − 2
/// gaps).
void main() {
  Future<void> openDashboard(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.dashboard,
    );
  }

  /// The location the router is currently showing.
  String currentLocation(WidgetTester tester) {
    final ctx = tester.element(find.byType(Navigator).first);
    return GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.toString();
  }

  testWidgets('is the landing page after a restored session', (tester) async {
    await openDashboard(tester);
    expect(find.text('대시보드'), findsWidgets);
  });

  testWidgets('the KPI row reports the seeded numbers', (tester) async {
    await openDashboard(tester);

    expect(find.text('오늘 예약'), findsOneWidget);
    expect(find.text('담당 고객'), findsOneWidget);
    expect(find.text('답장 필요'), findsOneWidget);
    expect(find.text('주의 고객'), findsOneWidget);

    // 2 of 3 clients active, 4 unread across 3 threads.
    expect(find.text('휴면 1명'), findsOneWidget);
    expect(find.text('고객 3명 대기 중'), findsOneWidget);
  });

  testWidgets('a KPI deep-links into the pre-filtered roster', (tester) async {
    await openDashboard(tester);

    await tester.tap(find.text('답장 필요'));
    await settle(tester);
    // The number and the list it opens have to be the same claim.
    expect(currentLocation(tester), contains('f=unread'));
  });

  testWidgets('오늘의 일정 lists today’s sessions and their status', (tester) async {
    await openDashboard(tester);

    expect(find.text('오늘의 일정'), findsOneWidget);
    expect(find.text('김민수 · 1:1 PT'), findsWidgets);
    expect(find.text('완료'), findsWidgets);
    // Gaps are shown but muted — a free hour is information.
    expect(find.text('빈 시간'), findsWidgets);
  });

  testWidgets('주의 고객 rows carry the reason and open the section that '
      'fixes it', (tester) async {
    await openDashboard(tester);

    expect(find.text('주의가 필요한 고객'), findsOneWidget);
    // Every seeded client has unread replies, and an unanswered message
    // outranks a sodium overshoot — so that is the badge each one shows.
    expect(find.text('답장 대기'), findsNWidgets(3));

    await tester.tap(find.text('답장 대기').first);
    await settle(tester);
    expect(currentLocation(tester), contains('/chat'));
  });

  testWidgets('the AI summary leads with the reply backlog', (tester) async {
    await openDashboard(tester);

    expect(find.text('AI 코칭 요약'), findsOneWidget);
    expect(find.textContaining('답장을 기다리고'), findsOneWidget);
  });

  testWidgets('AI 루틴 만들기 opens the coaching workspace', (tester) async {
    await openDashboard(tester);

    await tester.tap(find.text('AI 루틴 만들기').first);
    await settle(tester);
    expect(currentLocation(tester), AppRoutes.coaching);
  });

  testWidgets('the weekly chart renders one bar per weekday', (tester) async {
    await openDashboard(tester);

    expect(find.text('주간 세션 이행률'), findsOneWidget);
    for (final day in const <String>['월', '화', '수', '목', '금', '토', '일']) {
      expect(find.text(day), findsWidgets, reason: '$day 막대 라벨이 없어요');
    }
  });

  group('AttentionCard.sectionFor', () {
    test('each alert opens the sub-tab that actually addresses it', () {
      // The row is a shortcut to the fix, not just to the client.
      expect(AttentionCard.sectionFor(ClientAlert.unanswered), 'chat');
      expect(AttentionCard.sectionFor(ClientAlert.sodiumOver), 'diet');
      expect(AttentionCard.sectionFor(ClientAlert.lowCompletion), 'workout');
    });

    test('every alert has a destination', () {
      for (final alert in ClientAlert.values) {
        expect(
          AppRoutes.clientSections,
          contains(AttentionCard.sectionFor(alert)),
          reason: '${alert.label}의 이동 대상이 없는 섹션이에요',
        );
      }
    });
  });
}
