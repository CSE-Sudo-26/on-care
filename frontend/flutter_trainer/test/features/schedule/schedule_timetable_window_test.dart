/// 주간 시간표의 표시 구간과 높이. (#1010)
///
/// 창이 07:00 에서 시작하던 때에는 첫 라벨을 올릴 자리가 없어 `07:00` 이 카드
/// 경계에 잘렸고, 한 칸이 104px 로 고정이라 어떤 화면에서도 하루가 한 화면에
/// 들어오지 않았다. 여기서 재는 것은 그 두 가지다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_week_timetable.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> openSchedule(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );
  }

  Finder gutterLabel(String at) => find.descendant(
    of: find.byType(ScheduleWeekTimetable),
    matching: find.text(at),
  );

  ScrollableState grid(WidgetTester tester) => tester.state(
    find.descendant(
      of: find.byKey(const Key('schedule-timetable-scroll')),
      matching: find.byType(Scrollable),
    ),
  );

  testWidgets('창이 07:30 에서 시작해 23:30 에서 끝난다', (tester) async {
    await openSchedule(tester, const Size(1440, 1200));

    // 07:00 은 창 밖이다 — 라벨을 올릴 자리가 없어 잘리느니 넣지 않는다.
    expect(gutterLabel('07:00'), findsNothing);
    expect(gutterLabel('08:00'), findsOneWidget);
    expect(gutterLabel('23:00'), findsOneWidget);
  });

  testWidgets('시간축의 첫·마지막 라벨이 카드 안에 온전히 들어온다', (tester) async {
    await openSchedule(tester, const Size(1440, 1200));

    Rect scroll() =>
        tester.getRect(find.byKey(const Key('schedule-timetable-scroll')));

    // 첫 라벨은 격자 맨 위에 있다 — 07:00 을 창에 넣던 때에는 여기서 잘렸다.
    final Rect first = tester.getRect(gutterLabel('08:00'));
    expect(first.top, greaterThanOrEqualTo(scroll().top - 0.5));
    expect(first.bottom, lessThanOrEqualTo(scroll().bottom + 0.5));

    // 마지막 라벨은 끝까지 스크롤해서 본다.
    await tester.drag(
      find.byKey(const Key('schedule-timetable-scroll')),
      const Offset(0, -2000),
    );
    await tester.pump();
    final Rect last = tester.getRect(gutterLabel('23:00'));
    expect(last.top, greaterThanOrEqualTo(scroll().top - 0.5));
    expect(last.bottom, lessThanOrEqualTo(scroll().bottom + 0.5));
  });

  testWidgets('창 밖의 일정을 만들면 격자가 그 시각까지 넓어진다', (tester) async {
    await openSchedule(tester, const Size(1440, 1200));
    expect(gutterLabel('06:00'), findsNothing);

    await tester.tap(find.text('새 일정'));
    await settle(tester);
    await tester.tap(find.text('10시').first);
    await settle(tester);
    await tester.tap(find.text('06시').last);
    await settle(tester);
    await tester.tap(find.text('추가하기'));
    await settle(tester);

    // 화면에 없는 일정은 없는 일정과 같다.
    expect(gutterLabel('06:00'), findsOneWidget);
    expect(find.text('06:00\u201307:00'), findsOneWidget);
  });

  testWidgets('높이가 넉넉하면 스크롤 없이 하루가 통째로 보인다', (tester) async {
    await openSchedule(tester, const Size(1440, 1600));

    expect(
      grid(tester).position.maxScrollExtent,
      0,
      reason: '남는 높이에 맞춰 칸이 줄어 스크롤이 사라져야 한다',
    );
    // 그래도 블록은 시각과 이름 두 줄을 지킨다.
    expect(find.text('10:00\u201311:00'), findsWidgets);
    expect(find.text('김민수'), findsWidgets);
  });

  testWidgets('최소 높이로도 모자라면 스크롤로 나머지를 본다', (tester) async {
    await openSchedule(tester, const Size(1440, 700));

    expect(
      grid(tester).position.maxScrollExtent,
      greaterThan(0),
      reason: '칸을 더 줄이면 이름 줄이 사라진다 — 그 아래로는 스크롤한다',
    );
    expect(find.text('김민수'), findsWidgets);
  });
}
