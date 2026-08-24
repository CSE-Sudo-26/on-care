/// 초록이 무엇을 말하는가. (#1239)
///
/// 같은 `완료` 가 화면마다 다른 초록으로 보였다 — 두 앱이 함께 쓰는 `#34C759`
/// 옆에 어두운 초록(`#22A882`), 성취 초록(`#22C55E`), 온라인 점(`#4ADE80`)이
/// 뒤섞여 있었다. 뜻을 셋으로 갈라 두고, 같은 뜻이면 같은 값을 쓴다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/design_system/atoms/app_badge.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';

void main() {
  test('완료·성공 초록은 두 앱이 같은 값(#34C759)이다', () {
    // 트레이너 앱 `AppColors.success` 도 같은 값이다 — 두 패키지가 서로를
    // 참조하지 않으므로 양쪽 테스트가 같은 상수를 지킨다.
    expect(AppColors.success, const Color(0xFF34C759));
    expect(FigmaColors.statusGreen, AppColors.success);
  });

  test('성취는 완료와 다른 뜻이라 다른 초록이다', () {
    expect(AppColors.achievement, const Color(0xFF22C55E));
    expect(AppColors.achievement, isNot(AppColors.success));
    // 건강 점수 카드의 그라디언트와 한 짝이다.
    expect(AppColors.achievement, AppColors.scoreGradientStart);
  });

  test('식단 그래프는 판단을 담지 않는 브랜드색이다 — 초록이 아니다', () {
    expect(AppColors.dietChart, AppColors.primary);
    expect(AppColors.dietChart, isNot(AppColors.success));
    expect(AppColors.dietChart, isNot(FigmaColors.greenText));
  });

  testWidgets('성취 배지와 완료 배지는 서로 다른 초록으로 그려진다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              AppBadge(label: '완료', tone: AppBadgeTone.success),
              AppBadge(label: '성취', tone: AppBadgeTone.achievement),
            ],
          ),
        ),
      ),
    );

    Color colorOf(String label) => tester
        .widget<Text>(find.text(label))
        .style!
        .color!;

    expect(colorOf('완료'), AppColors.success);
    expect(colorOf('성취'), AppColors.achievement);
  });
}
