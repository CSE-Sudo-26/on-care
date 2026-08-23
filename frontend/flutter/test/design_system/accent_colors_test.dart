/// 같은 뜻은 같은 색으로 (#1060).
///
/// 하단 `+` 메뉴만 식단이 파랑, 운동이 초록이었다. 앱 안에서는 식단 그래프가
/// 초록, 운동 그래프가 파랑이라 같은 두 영역이 자리마다 색이 뒤바뀌었다.
///
/// 헤더 알림 점은 주황이라 같은 화면의 `주의` 색과 겹쳤다. 읽지 않은 알림은
/// 주의가 아니라 새 소식이다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';

void main() {
  testWidgets('알림 점은 주황이 아니라 빨강이다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FigmaCircleButton(
            icon: Icons.notifications_none_rounded,
            showDot: true,
          ),
        ),
      ),
    );

    final FigmaCircleButton bell = tester.widget<FigmaCircleButton>(
      find.byType(FigmaCircleButton),
    );
    expect(bell.dotColor, FigmaColors.redDot);
    expect(bell.dotColor, isNot(FigmaColors.orange));
  });
}
