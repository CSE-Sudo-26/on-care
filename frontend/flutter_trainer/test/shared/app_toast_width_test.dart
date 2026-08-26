/// 토스트 너비 규칙. (#1466)
///
/// 동작 버튼이 없는 안내는 내용만큼만 넓다 — `추천하지 않아요` 한 줄짜리 말이
/// 최대 너비(560)를 거의 채우면 짧은 말이 크게 보인다. 동작 버튼이 있는
/// 토스트(리포트 전송 완료의 `채팅으로 이동`)는 고정 너비를 지킨다: 메시지
/// 길이에 따라 버튼이 좌우로 흔들리면 누를 자리가 매번 달라진다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/design_system/tokens/toast.dart';
import 'package:oncare_trainer/shared/widgets/app_toast.dart';

void main() {
  /// 토스트를 띄우고 그 알약(Material)의 너비를 잰다.
  Future<double> toastWidth(
    WidgetTester tester,
    String message, {
    AppToastAction? action,
    Size size = const Size(1200, 800),
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    AppToastHost.of(ctx).show(message, action: action);
    await tester.pumpAndSettle();

    final Finder pill = find.ancestor(
      of: find.text(message),
      matching: find.byType(Material),
    );
    return tester.getSize(pill.first).width;
  }

  testWidgets('동작 버튼이 없는 짧은 토스트는 내용 너비로 선다', (tester) async {
    final double narrow = await toastWidth(tester, '저장했어요');

    expect(narrow, lessThan(AppToastStyle.maxWidth));
  });

  testWidgets('메시지가 길어지면 최대 너비까지만 넓어진다', (tester) async {
    final double short = await toastWidth(tester, '저장했어요');
    final double long = await toastWidth(
      tester,
      '홍슈 회전 스트레칭은(는) 추천하지 않아요. 다음 세션에서는 대체 동작을 함께 정해 보세요. '
      '이 문구는 최대 너비를 넘을 만큼 깁니다.',
    );

    expect(long, greaterThan(short));
    expect(long, lessThanOrEqualTo(AppToastStyle.maxWidth));
  });

  testWidgets('종류가 달라도 같은 너비 규칙을 쓴다', (tester) async {
    final double info = await toastWidth(tester, '같은 길이의 안내 문구');
    final double error = await toastWidth(tester, '같은 길이의 안내 문구');

    expect(info, error);
  });

  testWidgets('동작 버튼이 있는 토스트는 고정 너비를 지킨다', (tester) async {
    final double withAction = await toastWidth(
      tester,
      '리포트를 보냈어요',
      action: AppToastAction(label: '채팅으로 이동', onTap: () {}),
    );

    expect(withAction, AppToastStyle.maxWidth);
  });

  testWidgets('좁은 화면에서는 좌우 여백 안으로 줄어든다', (tester) async {
    final double onNarrowScreen = await toastWidth(
      tester,
      '리포트를 보냈어요',
      action: AppToastAction(label: '채팅으로 이동', onTap: () {}),
      size: const Size(360, 800),
    );

    expect(onNarrowScreen, lessThan(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('큰 배율에서도 넘치지 않는다', (tester) async {
    await toastWidth(
      tester,
      '홍슈 회전 스트레칭은(는) 추천하지 않아요',
      size: const Size(360, 800),
      textScale: 1.6,
    );

    expect(tester.takeException(), isNull);
  });
}
