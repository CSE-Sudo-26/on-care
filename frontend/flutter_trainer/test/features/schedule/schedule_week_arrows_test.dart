/// 주 이동 화살표. (#1009)
///
/// 배경 없는 회색 아이콘이던 때에는 어디까지가 눌리는 범위인지 형태로 알 수
/// 없었고, 주변 글씨와 같은 계열이라 "누르는 것" 으로 읽히지도 않았다. 색을
/// 아이콘이 아니라 **원 영역**에 준다는 것이 여기서 재는 계약이다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> openSchedule(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );
  }

  Finder arrow(IconData icon) =>
      find.byKey(ValueKey<String>('schedule-week-arrow-${icon.codePoint}'));

  ({Color? color, BoxShape shape}) circle(WidgetTester tester, IconData icon) {
    final decoration =
        tester.widget<Container>(arrow(icon)).decoration! as BoxDecoration;
    return (color: decoration.color, shape: decoration.shape);
  }

  testWidgets('화살표가 색이 있는 원형 타깃으로 그려진다', (tester) async {
    await openSchedule(tester);

    for (final icon in <IconData>[Icons.chevron_left, Icons.chevron_right]) {
      final drawn = circle(tester, icon);
      expect(drawn.shape, BoxShape.circle, reason: '$icon 이 원이어야 한다');
      expect(drawn.color, AppColors.primary, reason: '색은 아이콘이 아니라 원 영역에 있다');
    }

    // 두 원의 크기가 같다 — 한쪽만 커 보이면 두 방향의 무게가 달라 보인다.
    expect(
      tester.getSize(arrow(Icons.chevron_left)),
      tester.getSize(arrow(Icons.chevron_right)),
    );

    // 아이콘은 원 안에서 대비되는 색으로 남는다.
    final Icon glyph = tester.widget<Icon>(
      find.descendant(
        of: arrow(Icons.chevron_right),
        matching: find.byIcon(Icons.chevron_right),
      ),
    );
    expect(glyph.color, AppColors.primaryForeground);
  });

  testWidgets('눌러서 지난 주·다음 주로 오간다', (tester) async {
    await openSchedule(tester);
    expect(find.text('김민수'), findsWidgets); // 오늘이 보이는 주

    await tester.tap(arrow(Icons.chevron_right));
    await settle(tester);
    expect(find.text('김민수'), findsNothing, reason: '다음 주에는 시드가 없다');

    await tester.tap(arrow(Icons.chevron_left));
    await settle(tester);
    expect(find.text('김민수'), findsWidgets);
  });

  testWidgets('좁은 폭과 큰 글자 배율에서도 날짜 행이 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openSchedule(tester, size: const Size(360, 720));

    expect(arrow(Icons.chevron_left), findsOneWidget);
    expect(arrow(Icons.chevron_right), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
