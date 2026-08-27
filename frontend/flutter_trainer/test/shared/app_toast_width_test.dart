/// 토스트 너비 규칙. (#1466, #1571, #1573)
///
/// 동작 버튼이 있든 없든 토스트는 내용만큼만 넓다 — `추천하지 않아요` 한 줄짜리
/// 말이나 `리포트를 보냈어요` + `채팅으로 이동` 조합이나 최대 너비(560)를
/// 고정으로 채우면 짧은 말이 크게 보이고, 버튼이 텍스트에서 멀리 떨어진
/// 오른쪽 빈 자리에 걸린다. 버튼은 텍스트 바로 오른쪽 끝에 간격을 두고 붙는다.
///
/// 메시지가 최대 너비를 넘어도 두 번째 줄로 넘어가지 않는다 — 항상 한 줄로
/// 서고, 넘치는 부분은 말줄임표로 자른다.
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

  /// 토스트를 띄우고 그 알약(Material)의 높이를 잰다.
  Future<double> toastHeight(WidgetTester tester, String message) async {
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
    AppToastHost.of(ctx).show(message);
    await tester.pumpAndSettle();

    final Finder pill = find.ancestor(
      of: find.text(message),
      matching: find.byType(Material),
    );
    return tester.getSize(pill.first).height;
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

  testWidgets('동작 버튼이 있어도 내용 너비로 선다', (tester) async {
    final double withAction = await toastWidth(
      tester,
      '리포트를 보냈어요',
      action: AppToastAction(label: '채팅으로 이동', onTap: () {}),
    );

    expect(withAction, lessThan(AppToastStyle.maxWidth));
  });

  testWidgets('동작 버튼은 텍스트 오른쪽 끝에 간격을 두고 붙는다', (tester) async {
    const String message = '리포트를 보냈어요';
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    AppToastHost.of(ctx).show(
      message,
      action: AppToastAction(label: '채팅으로 이동', onTap: () {}),
    );
    await tester.pumpAndSettle();

    final Rect pill = tester.getRect(
      find
          .ancestor(of: find.text(message), matching: find.byType(Material))
          .first,
    );
    final Rect text = tester.getRect(find.text(message));
    final Rect action = tester.getRect(
      find.byKey(const ValueKey<String>('app-toast-action')),
    );

    // 버튼이 알약의 오른쪽 끝(안쪽 여백만큼 안쪽)에 붙는다.
    expect(pill.right - action.right, closeTo(16, 1));
    // 텍스트와 버튼 사이에 눈에 띄는 간격이 있다.
    expect(action.left - text.right, greaterThan(8));
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

  testWidgets('아무리 길어도 두 줄로 넘어가지 않는다', (tester) async {
    final double oneLine = await toastHeight(tester, '저장했어요');
    final double veryLong = await toastHeight(
      tester,
      'AI 루틴이 프로그램 정보에 반영됐어요. 아래에서 확인하고 필요하면 수정한 뒤 '
      '보내기로 전달하세요. 이 문구는 한 줄 높이를 훌쩍 넘길 만큼 깁니다.',
    );

    expect(veryLong, oneLine);
  });
}
