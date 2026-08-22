/// 그래프 목표치는 어디에 어떻게 적히는가 (#1071).
///
/// 목표선은 모든 그래프에 들어갔지만 목표치 라벨은 그래프마다 다른 자리에
/// 있었다 — 어떤 곳은 점선 오른쪽 끝, 어떤 곳은 알약 배지, 어떤 곳은 왼쪽 축
/// 칸. 홈 탭 식단 영양 그래프가 쓰던 **왼쪽 칸 · 두 줄**로 통일했고, 이 파일이
/// 그 자리를 지킨다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/design_system/charts/goal_line.dart';
import 'package:oncare/design_system/charts/period_scroll_chart.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
);

void main() {
  testWidgets('목표치는 첫 줄 `목표`, 둘째 줄 목표치로 적힌다', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        const ChartGoalAxis(height: 100, label: '목표\n2,000', lineBottom: 50),
      ),
    );

    final Text label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(chartGoalLabelKey),
        matching: find.byType(Text),
      ),
    );
    expect(label.data, '목표\n2,000');
    expect(label.maxLines, 2, reason: '두 줄 구성이 무너지면 칸 폭이 넓어진다');
    expect(label.textAlign, TextAlign.right);
  });

  testWidgets('목표치 칸은 목표가 없어도 폭을 지킨다', (WidgetTester tester) async {
    // 실제로는 Row 안에 놓인다 — 폭을 꽉 채우는 부모에 바로 넣으면 칸이
    // 부모 폭으로 늘어나 무엇을 재는지 알 수 없다.
    await tester.pumpWidget(
      _app(
        const Row(children: <Widget>[ChartGoalAxis(height: 100), Spacer()]),
      ),
    );

    expect(find.byKey(chartGoalLabelKey), findsNothing);
    expect(
      tester.getSize(find.byType(ChartGoalAxis)).width,
      chartGoalAxisWidth,
      reason: '목표가 없다고 칸이 사라지면 지표를 바꿀 때 그래프 폭이 흔들린다',
    );
  });

  testWidgets('라벨은 목표선 높이를 따라간다', (WidgetTester tester) async {
    Future<double> topOf(double lineBottom) async {
      await tester.pumpWidget(
        _app(
          ChartGoalAxis(
            height: 200,
            label: '목표\n2,000',
            lineBottom: lineBottom,
          ),
        ),
      );
      return tester.getRect(find.byKey(chartGoalLabelKey)).center.dy;
    }

    final double low = await topOf(20);
    final double high = await topOf(180);
    expect(
      high,
      lessThan(low),
      reason: '목표가 높을수록 라벨도 위에 앉아야 선과 같은 높이가 된다',
    );
  });

  testWidgets('기간 그래프의 막대는 목표치 칸 오른쪽에서 시작한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          height: 140,
          child: PeriodScrollChart(
            count: 7,
            height: 100,
            goalBottom: 50,
            goalLabel: '목표\n2,000',
            labelBuilder: (int i) => '$i',
            onVisibleRangeChanged: (_, _) {},
            calloutBuilder: (BuildContext context, int i) =>
                const SizedBox.shrink(),
            barBuilder: (BuildContext context, int i) =>
                const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect axis = tester.getRect(find.byType(ChartGoalAxis));
    final Rect scroller = tester.getRect(
      find.byType(SingleChildScrollView).first,
    );
    expect(
      scroller.left,
      greaterThanOrEqualTo(axis.right),
      reason: '목표치가 왼쪽에 들어갔으니 그래프는 그만큼 오른쪽으로 밀려야 한다',
    );
    expect(axis.left, lessThan(scroller.left));
  });
}
