import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';

import '../../helpers/pump_app.dart';

/// 일정 카드의 `1:1 PT · 60분` 은 **이 약속이 무엇인가**를 말한다. (#938)
///
/// 프로필 열 세 번째 줄에 가장 흐린 색으로 두었더니 회원의 부가 정보처럼
/// 읽혔다. 비어 있던 오른쪽 여백으로 옮겨 상태 칩 옆에 세운다.
void main() {
  Future<void> openSchedule(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );
    await tester.pumpAndSettle();
  }

  Finder chip() => find.byKey(const ValueKey<String>('session-type-chip'));

  testWidgets('세션 종류·소요 시간이 카드 오른쪽 알약으로 보인다', (tester) async {
    await openSchedule(tester);

    expect(chip(), findsWidgets);
    final Finder first = chip().first;
    expect(
      find.descendant(of: first, matching: find.textContaining('분')),
      findsOneWidget,
    );

    // 이름·목표가 있는 왼쪽 열이 아니라, 그 오른쪽에 선다.
    final Finder name = find.text('김민수').first;
    expect(
      tester.getRect(first).left,
      greaterThan(tester.getRect(name).right),
      reason: '프로필 열의 세 번째 줄로 읽히면 안 된다',
    );
  });

  testWidgets('알약 글자는 목표 줄보다 뚜렷하다', (tester) async {
    await openSchedule(tester);

    final List<Text> labels = <Text>[
      for (final Element e in chip().evaluate())
        tester.widget<Text>(
          find
              .descendant(
                of: find.byWidget(e.widget),
                matching: find.byType(Text),
              )
              .first,
        ),
    ];
    expect(labels, isNotEmpty);
    // 목표 줄은 11.5px · w500 · subtleForeground 다. 같은 무게로 두면 옮겨도
    // 여전히 부가 정보로 읽힌다.
    for (final Text label in labels) {
      expect(label.style!.fontWeight, FontWeight.w800);
    }
    // 끝난 세션만 상태 칩과 함께 물러나고, 나머지는 브랜드 남색이다.
    expect(labels.map((Text t) => t.style!.color), contains(AppColors.primary));
    for (final Text label in labels) {
      expect(
        label.style!.color,
        anyOf(AppColors.primary, AppColors.disabledForeground),
      );
    }
  });

  testWidgets('좁아지면 알약이 먼저 줄어들고 카드는 넘치지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );
    await tester.pumpAndSettle();

    // 이름과 상태는 잘리면 안 되는 값이라, 글자를 자르는 대신 알약을 통째로
    // 작게 그린다.
    expect(
      find.ancestor(of: chip().first, matching: find.byType(FittedBox)),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
