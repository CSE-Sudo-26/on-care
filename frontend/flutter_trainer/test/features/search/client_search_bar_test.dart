import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> openDesktop(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(tester, token: 'demo-trainer-token', at: route);
  }

  testWidgets('대시보드와 일정에는 전역 회원 검색을 노출하지 않는다', (tester) async {
    await openDesktop(tester, AppRoutes.dashboard);
    expect(find.byKey(clientSearchFieldKey), findsNothing);

    GoRouter.of(tester.element(find.text('대시보드').last)).go(AppRoutes.schedule);
    await settle(tester);
    expect(find.byKey(clientSearchFieldKey), findsNothing);
  });

  testWidgets('회원 관리는 목록 문맥 안에서 이름을 필터링한다', (tester) async {
    await openDesktop(tester, AppRoutes.clients);

    final field = find.byKey(const ValueKey<String>('clients-roster-search'));
    expect(field, findsOneWidget);
    await tester.enterText(field, '김민수');
    await settle(tester);

    expect(find.text('김민수'), findsWidgets);
    expect(find.text('박성호'), findsNothing);
  });

  testWidgets('프로그램 검색은 회원별 프로그램 목록 안에 있다', (tester) async {
    await openDesktop(tester, AppRoutes.coaching);

    expect(find.byKey(clientSearchFieldKey), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('program-member-search')),
      findsOneWidget,
    );
  });
}
