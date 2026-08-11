import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';

import '../../helpers/pump_app.dart';

/// 콘솔 헤더의 고객 검색.
///
/// 한 컨트롤이지만 탭마다 다른 답을 해야 한다 — 결과 줄에 그 탭이 묻는
/// 사실을 보여 주고, 선택하면 그 탭이 가진 화면으로 보낸다. 그래서
/// 여기서 확인하는 것은 "검색이 되는가"가 아니라 **탭마다 다르게
/// 되는가**다.
void main() {
  final Finder results = find.byKey(clientSearchResultsKey);

  /// 검색어를 입력하고 드롭다운이 뜰 때까지 기다린다.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(clientSearchFieldKey), query);
    await settle(tester);
  }

  /// 드롭다운 안의 [name] 행. 뒤에 깔린 목록에도 같은 이름이 있으므로
  /// 반드시 결과 카드 안으로 좁혀서 찾는다.
  Finder row(String name) =>
      find.descendant(of: results, matching: find.text(name));

  /// 현재 URL.
  String location(WidgetTester tester) => GoRouter.of(
    tester.element(find.byKey(clientSearchFieldKey)),
  ).state.uri.toString();

  Future<void> openConsole(WidgetTester tester, String at) async {
    // 인라인 필드는 헤더가 남겨 준 폭에서만 그려진다 — 좁은 화면에서는
    // 아이콘 + 다이얼로그 형태이므로 넓은 콘솔로 띄운다.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(tester, token: 'demo-trainer-token', at: at);
  }

  testWidgets('고객 탭 — 검색해서 고른 고객이 보고 있던 하위 탭으로 열린다', (tester) async {
    await openConsole(
      tester,
      AppRoutes.clientDetail('seed-client-3', section: 'workout'),
    );

    await search(tester, '김민수');
    expect(results, findsOneWidget);
    expect(find.text('선택하면 고객 상세가 열려요'), findsOneWidget);

    await tester.tap(row('김민수'));
    await settle(tester);

    // 식단으로 리셋되지 않는다 — 운동을 보던 중이었다.
    expect(location(tester), '/clients/seed-client-1/workout');
  });

  testWidgets('리포트 탭 — 이번 주 이행률을 보여 주고 그 고객 리포트를 연다', (tester) async {
    await openConsole(tester, AppRoutes.reports);

    await search(tester, '김민수');
    expect(find.text('선택하면 주간 리포트를 열어요'), findsOneWidget);
    expect(
      find.descendant(of: results, matching: find.textContaining('이번 주')),
      findsOneWidget,
      reason: '리포트 탭의 관심사는 그 주의 이행률이다',
    );

    await tester.tap(row('김민수'));
    await settle(tester);

    expect(location(tester), '/reports?client=seed-client-1');
  });

  testWidgets('AI 코칭 탭 — 마지막 루틴을 보여 주고 워크스페이스로 불러온다', (tester) async {
    await openConsole(tester, AppRoutes.coaching);

    await search(tester, '김민수');
    expect(find.text('선택하면 AI 코칭에 불러와요'), findsOneWidget);
    expect(
      find.descendant(of: results, matching: find.textContaining('루틴')),
      findsOneWidget,
    );

    await tester.tap(row('김민수'));
    await settle(tester);

    expect(location(tester), '/coaching?client=seed-client-1');
  });

  testWidgets('스케줄 탭 — 다음 예약이 있는 고객은 그 날짜로 이동한다', (tester) async {
    await openConsole(tester, AppRoutes.schedule);

    // 시드는 오늘 박성호의 예정 세션을 하나 갖고 있다.
    await search(tester, '박성호');
    expect(find.text('선택하면 다음 예약 날짜로 이동해요'), findsOneWidget);
    // 시드 세션은 오늘 잡혀 있으므로 날짜 라벨까지 확인한다 (푸터 문구에도
    // '다음 예약'이 들어가므로 그것만으로는 좁혀지지 않는다).
    expect(
      find.descendant(of: results, matching: find.textContaining('다음 예약 오늘')),
      findsOneWidget,
    );

    await tester.tap(row('박성호'));
    await settle(tester);

    expect(location(tester), '/schedule?v=day&d=${ymd(DateTime.now())}');
  });

  testWidgets('스케줄 탭 — 예정된 예약이 없으면 고객 상세로 이어진다', (tester) async {
    await openConsole(tester, AppRoutes.schedule);

    // 김민수의 오늘 세션은 완료 상태라 다음 예약이 아니다.
    await search(tester, '김민수');
    expect(
      find.descendant(of: results, matching: find.text('예정된 예약 없음')),
      findsOneWidget,
    );

    await tester.tap(row('김민수'));
    await settle(tester);

    expect(location(tester), '/clients/seed-client-1/diet');
  });

  testWidgets('대시보드 탭 — 오늘 챙길 이유를 보여 주고 고객 상세로 넘긴다', (tester) async {
    await openConsole(tester, AppRoutes.dashboard);

    await search(tester, '김민수');
    // 김민수는 나트륨 초과 시드다 — 대시보드가 묻는 것이 그것이다.
    expect(
      find.descendant(of: results, matching: find.textContaining('나트륨 초과')),
      findsOneWidget,
    );

    await tester.tap(row('김민수'));
    await settle(tester);

    expect(location(tester), '/clients/seed-client-1/diet');
  });

  testWidgets('일치하는 고객이 없으면 그렇게 말한다', (tester) async {
    await openConsole(tester, AppRoutes.clients);

    await search(tester, '홍길동');

    expect(find.textContaining('일치하는 고객이 없어요'), findsOneWidget);
  });

  testWidgets('가장 붐비는 헤더(스케줄)도 콘솔 최소 폭에서 넘치지 않는다', (tester) async {
    // 스케줄 헤더는 세그먼트 스위치까지 네 개의 액션을 단다. 검색은 그
    // 나머지를 받는 쪽이라 좁아질 뿐 헤더를 밀어내지 않아야 한다 —
    // Flutter 는 오버플로에 예외를 던지므로 그리는 것 자체가 검증이다.
    tester.view.physicalSize = const Size(
      AppLayout.sidebarDrawerBreakpoint,
      900,
    );
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(clientSearchFieldKey), findsOneWidget);
  });

  testWidgets('드로어 폭에서는 아이콘으로 접히고, 눌러 연 검색도 같은 곳으로 보낸다', (tester) async {
    // 기본 테스트 화면(800x600)은 셸이 드로어 형태로 접히는 폭이다.
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clients,
    );

    expect(find.byKey(clientSearchFieldKey), findsNothing);
    await tester.tap(find.byKey(clientSearchIconKey));
    await settle(tester);

    await tester.enterText(find.byType(TextField).last, '김민수');
    await settle(tester);
    await tester.tap(row('김민수'));
    await settle(tester);

    final ctx = tester.element(find.byKey(clientSearchIconKey));
    expect(
      GoRouter.of(ctx).state.uri.toString(),
      '/clients/seed-client-1/diet',
    );
  });

  testWidgets('접힌 검색 다이얼로그도 ↓와 Enter로 다른 고객을 고른다', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clients,
    );

    await tester.tap(find.byKey(clientSearchIconKey));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '수');
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    final ctx = tester.element(find.byKey(clientSearchIconKey));
    expect(
      GoRouter.of(ctx).state.uri.toString(),
      '/clients/seed-client-2/diet',
      reason: '두 번째 검색 결과가 선택되어야 한다',
    );
  });

  testWidgets('검색어를 지우면 드롭다운이 닫힌다', (tester) async {
    await openConsole(tester, AppRoutes.clients);

    await search(tester, '김민수');
    expect(results, findsOneWidget);

    await search(tester, '');
    expect(results, findsNothing);
  });

  testWidgets('X 버튼은 입력칸의 글자까지 지운다', (tester) async {
    await openConsole(tester, AppRoutes.clients);

    await search(tester, '김민수');
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);

    // 상태만 비우고 컨트롤러를 두면, 이름은 그대로 보이는데 검색은 이미
    // 초기화된 상태가 된다.
    final field = tester.widget<TextField>(find.byKey(clientSearchFieldKey));
    expect(field.controller!.text, isEmpty);
    expect(results, findsNothing);
  });

  testWidgets('키보드만으로 고를 수 있다 — ↓ 가 하이라이트를 옮기고 Enter 가 연다', (tester) async {
    await openConsole(tester, AppRoutes.clients);

    // 콘솔은 마우스만 쓰는 화면이 아니다. '수'는 여러 고객을 잡으므로,
    // 같은 질의를 Enter 만 / ↓+Enter 로 두 번 실행해 하이라이트가 실제로
    // 다른 행을 가리켰는지 확인한다 (시드 순서에 기대지 않는 비교).
    await search(tester, '수');
    expect(
      tester
          .widgetList<Text>(
            find.descendant(of: results, matching: find.byType(Text)),
          )
          .where((t) => t.style?.fontWeight == FontWeight.w700)
          .length,
      greaterThan(1),
      reason: '결과가 둘 이상이어야 하이라이트 이동을 볼 수 있다',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    final first = location(tester);

    await search(tester, '수');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    final second = location(tester);

    expect(first, startsWith('/clients/'));
    expect(second, startsWith('/clients/'));
    expect(second, isNot(first), reason: '↓ 를 눌렀으니 다른 고객이 열려야 한다');
  });

  testWidgets('탭의 제목과 액션 수가 달라도 검색창 중심은 고정된다', (tester) async {
    await openConsole(tester, AppRoutes.dashboard);
    final dashboardCenter = tester.getCenter(find.byKey(clientSearchFieldKey));

    GoRouter.of(
      tester.element(find.byKey(clientSearchFieldKey)),
    ).go(AppRoutes.coaching);
    await settle(tester);
    final coachingCenter = tester.getCenter(find.byKey(clientSearchFieldKey));

    GoRouter.of(
      tester.element(find.byKey(clientSearchFieldKey)),
    ).go(AppRoutes.reports);
    await settle(tester);
    final reportsCenter = tester.getCenter(find.byKey(clientSearchFieldKey));

    expect(coachingCenter.dx, closeTo(dashboardCenter.dx, 0.1));
    expect(reportsCenter.dx, closeTo(dashboardCenter.dx, 0.1));
  });

  testWidgets('한 고객 결과에서 다른 탭으로 바로 이동할 수 있다', (tester) async {
    await openConsole(tester, AppRoutes.reports);
    await search(tester, '김민수');

    expect(
      find.descendant(
        of: results,
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuButton || widget is Tooltip,
        ),
      ),
      findsNothing,
      reason: '결과 오버레이 안에 또 다른 오버레이를 여는 위젯을 두지 않는다',
    );

    await tester.tap(find.byKey(clientSearchQuickActionsKey('seed-client-1')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(clientSearchDestinationKey('seed-client-1', 'coaching')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(clientSearchDestinationKey('seed-client-1', 'coaching')),
    );
    await settle(tester);

    expect(location(tester), '/coaching?client=seed-client-1');
  });
}
