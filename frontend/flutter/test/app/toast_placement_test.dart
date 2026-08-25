/// 토스트가 어디에, 무엇 위에 뜨는지 (#1259).
///
/// 두 가지를 지킨다. **모달 시트가 열려 있어도 보일 것** — 스낵바는 `Scaffold`
/// 안에 그려져 시트 뒤로 숨는데, 이 앱은 저장도 검증도 대부분 시트 안에서 한다.
/// 그리고 **화면 위쪽에 뜰 것** — 아래쪽은 하단 내비게이션과 `+` 버튼, 시트의
/// 저장 버튼, 키보드가 모두 몰려 있는 자리다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/theme/app_theme.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

const String _message = '기록을 저장했어요';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final GoRouter router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(AppRoutes.dashboard);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appConfigProvider.overrideWithValue(_config)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleToast(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// 남은 타이머·애니메이션을 끝까지 돌려 테스트가 깨끗하게 닫히게 한다.
  Future<void> letToastFade(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  void showToast(WidgetTester tester) {
    showAppToast(
      tester.element(find.byKey(const Key('recordAddButton'))),
      _message,
      kind: AppToastKind.success,
    );
  }

  testWidgets('토스트가 화면 위쪽에 뜬다', (WidgetTester tester) async {
    await pumpShell(tester);

    showToast(tester);
    await settleToast(tester);

    expect(find.text(_message), findsOneWidget);
    final Rect toast = tester.getRect(find.text(_message));
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(toast.center.dy, lessThan(screen.height / 4));

    await letToastFade(tester);
  });

  testWidgets('모달 시트가 열려 있어도 토스트가 시트 위에 뜬다', (WidgetTester tester) async {
    await pumpShell(tester);

    // `+` 로 기록 추가 시트를 연다.
    await tester.tap(find.byKey(const Key('recordAddButton')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    showToast(tester);
    await settleToast(tester);

    expect(find.text(_message), findsOneWidget);
    final Rect toast = tester.getRect(find.text(_message));
    final Rect sheet = tester.getRect(find.byType(BottomSheet));
    expect(toast.bottom, lessThan(sheet.top), reason: '토스트가 시트에 가린다');

    await letToastFade(tester);
  });

  testWidgets('눌러서 먼저 치울 수 있다', (WidgetTester tester) async {
    await pumpShell(tester);

    showToast(tester);
    await settleToast(tester);
    expect(find.text(_message), findsOneWidget);

    await tester.tap(find.text(_message));
    await tester.pumpAndSettle();

    expect(find.text(_message), findsNothing);
  });
}
