/// 토스트가 하단 바와 `+` 버튼을 비키는지 (#1259).
///
/// `+` 버튼은 `Scaffold` 의 FAB 이 아니라 하단 바 위젯 **안**에 들어 있어,
/// Flutter 는 이 버튼을 알지 못한다. 그래서 Material 기본값(`fixed`)으로 뜬
/// 토스트가 `+` 원과 겹치고 그 아래로 투명한 띠가 남았다. 테마가 토스트를
/// 떠 있는 형태로 바꿔 바 위젯 전체를 비키게 한 것이 이 고침이다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/theme/app_theme.dart';
import 'package:oncare/design_system/tokens/toast.dart';
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

  Future<void> showToast(WidgetTester tester) async {
    showAppToast(
      tester.element(find.byKey(const Key('recordAddButton'))),
      _message,
      kind: AppToastKind.success,
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('토스트가 + 버튼 위에 뜬다', (WidgetTester tester) async {
    await pumpShell(tester);
    final Rect addButton = tester.getRect(
      find.byKey(const Key('recordAddButton')),
    );

    await showToast(tester);

    expect(find.text(_message), findsOneWidget);
    // 눈에 보이는 알약의 자리로 잰다 — `SnackBar` 위젯의 상자에는 바깥 여백까지
    // 들어 있어, 붙어 버린 토스트와 떠 있는 토스트를 가르지 못한다.
    final Rect toast = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      addButton.top - toast.bottom,
      greaterThanOrEqualTo(AppToastStyle.bottomGap),
      reason: '토스트가 + 버튼에 닿는다',
    );
  });

  testWidgets('하단 바가 없는 화면에서는 화면 아래에 붙어 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => showAppToast(context, _message),
                child: const Text('띄우기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('띄우기'));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect toast = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    // 셸 밖에서는 비킬 바가 없다 — 화면 아래 끝에서 한 뼘만 떨어진다.
    expect(screen.height - toast.bottom, lessThan(40));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
