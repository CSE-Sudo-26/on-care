/// 주 이동 화살표. (#1009)
///
/// 배경 없는 회색 아이콘이던 때에는 어디까지가 눌리는 범위인지 형태로 알 수
/// 없었고, 주변 글씨와 같은 계열이라 "누르는 것" 으로 읽히지도 않았다. 색을
/// 아이콘이 아니라 **원 영역**에 준다는 것이 여기서 재는 계약이다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_date_nav_bar.dart';

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
      expect(
        drawn.color,
        AppColors.accentSurface,
        reason: '색은 아이콘이 아니라 원 영역에 있다',
      );
    }

    // 두 원의 크기가 같다 — 한쪽만 커 보이면 두 방향의 무게가 달라 보인다.
    expect(
      tester.getSize(arrow(Icons.chevron_left)),
      tester.getSize(arrow(Icons.chevron_right)),
    );

    // 아이콘은 연한 원 위에 남색으로 남는다 — 회원 앱 식단 탭과 같은 표현이다.
    final Icon glyph = tester.widget<Icon>(
      find.descendant(
        of: arrow(Icons.chevron_right),
        matching: find.byIcon(Icons.chevron_right),
      ),
    );
    expect(glyph.color, AppColors.primary);
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

  testWidgets('`오늘` 이 생겨도 화살표가 자리를 지킨다 (#1009)', (tester) async {
    await openSchedule(tester);
    // 오늘을 보고 있으면 `오늘` 은 뜨지 않는다.
    expect(find.text('오늘'), findsNothing);
    final Rect left = tester.getRect(arrow(Icons.chevron_left));
    final Rect right = tester.getRect(arrow(Icons.chevron_right));
    final Finder dateLabel = find.descendant(
      of: find.byType(ScheduleDateNavBar),
      matching: find.textContaining('월'),
    );
    final Rect date = tester.getRect(dateLabel);

    // 같은 주의 다른 날로 옮기면 `오늘` 이 나타난다.
    final today = todayKst();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final other = monday == today
        ? monday.add(const Duration(days: 1))
        : monday;
    await tester.tap(
      find.byKey(ValueKey<String>('schedule-day-${ymd(other)}')),
    );
    await settle(tester);
    expect(find.text('오늘'), findsOneWidget);

    // 버튼이 생겼는데도 화살표와 날짜가 그대로다 — 같은 버튼을 누르려고 매번
    // 다른 자리를 겨누게 만들지 않는다.
    expect(tester.getRect(arrow(Icons.chevron_left)), left);
    expect(tester.getRect(arrow(Icons.chevron_right)), right);
    expect(tester.getRect(dateLabel), date);

    // 그리고 그 자리는 두 화살표 사이의 **한가운데**다. `오늘` 자리를 날짜
    // 오른쪽에만 비워 두면 날짜가 그만큼 왼쪽으로 치우친다.
    expect(
      tester.getRect(dateLabel).center.dx,
      closeTo(
        (tester.getRect(arrow(Icons.chevron_left)).center.dx +
                tester.getRect(arrow(Icons.chevron_right)).center.dx) /
            2,
        1,
      ),
      reason: '날짜는 화살표 사이 한가운데에 선다',
    );
  });

  testWidgets('`오늘` 이 없을 때도 날짜가 화살표 사이 한가운데다 (#1009)', (tester) async {
    await openSchedule(tester);
    expect(find.text('오늘'), findsNothing);

    final Rect left = tester.getRect(arrow(Icons.chevron_left));
    final Rect right = tester.getRect(arrow(Icons.chevron_right));
    final Rect date = tester.getRect(
      find.descendant(
        of: find.byType(ScheduleDateNavBar),
        matching: find.textContaining('월'),
      ),
    );
    expect(date.center.dx, closeTo((left.center.dx + right.center.dx) / 2, 1));
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
