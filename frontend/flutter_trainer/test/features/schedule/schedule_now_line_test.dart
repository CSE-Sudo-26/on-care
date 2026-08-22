/// 주간 시간표의 현재 시각 선. (#1006)
///
/// 선이 열의 `build` 에서 시각을 한 번 읽던 때에는, 다시 그릴 이유가 없으면 그
/// 시점에 멈춰 있었다. 콘솔을 종일 띄워 두는 화면이라 벌어지는 폭이 몇 시간까지
/// 갔고 — 화면이 아는 척하면서 틀린 값을 가리켰다.
///
/// 시계를 [scheduleClockProvider] 로 뺀 덕에 테스트가 그 값을 쥔다. 여기서 재는
/// 것은 "시각이 흐르면 선이 그만큼 내려온다" 는 계약이다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/clock_provider.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_week_timetable.dart';

import '../../helpers/pump_app.dart';

/// 테스트가 손으로 미는 시계.
class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;
}

void main() {
  /// 시계를 테스트가 쥔 채 스케줄 탭을 띄운다. 시작 시각은 창(07~22시) 안이다.
  Future<_FakeClock> openSchedule(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final clock = _FakeClock(todayKst().add(const Duration(hours: 9)));
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
      extraOverrides: <Override>[
        scheduleClockProvider.overrideWithValue(clock.call),
      ],
    );
    return clock;
  }

  Finder nowLine() => find.byKey(const Key('schedule-now-line'));

  /// 한 시간 칸의 높이. 남는 높이에 맞춰 정해지므로(#1010) 상수로 잡을 수 없다
  /// — 시간축의 이웃한 두 라벨 사이가 곧 그 값이다.
  double hourHeight(WidgetTester tester) {
    Rect label(String at) => tester.getRect(
      find.descendant(
        of: find.byType(ScheduleWeekTimetable),
        matching: find.text(at),
      ),
    );
    return label('10:00').top - label('09:00').top;
  }

  testWidgets('시각이 흐르면 현재 시각 선이 그만큼 내려온다', (tester) async {
    final clock = await openSchedule(tester);
    final double at9 = tester.getRect(nowLine()).top;

    // 정각에 맞춘 첫 타이머가 1분 뒤에 깨어난다. 그때 시계는 이미 30분 흘렀다.
    clock.now = clock.now.add(const Duration(minutes: 30));
    await tester.pump(const Duration(minutes: 1));

    expect(
      tester.getRect(nowLine()).top - at9,
      closeTo(hourHeight(tester) / 2, 0.5),
      reason: '30분이 지나면 한 칸의 절반만큼 내려와야 한다',
    );
  });

  testWidgets('보이는 창 밖의 시각에는 선을 그리지 않는다', (tester) async {
    // 기본 창은 07~22시다. 격자에 없는 시각을 가리키는 선은 자리를 잘못 짚은
    // 것과 같아, 아무것도 그리지 않는 편이 옳다.
    final clock = await openSchedule(tester);
    expect(nowLine(), findsOneWidget);

    clock.now = todayKst().add(const Duration(hours: 3));
    await tester.pump(const Duration(minutes: 1));

    expect(nowLine(), findsNothing);
  });

  testWidgets('보이는 주에 오늘이 없으면 선도 없다', (tester) async {
    await openSchedule(tester);
    expect(nowLine(), findsOneWidget);

    // 다음 주로 넘기면 오늘 열 자체가 없다 — 선을 그릴 자리도, 타이머를 돌릴
    // 이유도 사라진다.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await settle(tester);

    expect(nowLine(), findsNothing);
  });

  testWidgets('선이 다시 그려져도 세션 블록은 그대로다', (tester) async {
    // 열 전체가 1분마다 다시 그려지면 그 안의 블록 수만큼 재빌드가 따라온다.
    // 블록의 Element 가 같은 인스턴스로 남아 있는지로 그것을 확인한다.
    final clock = await openSchedule(tester);
    final Finder block = find
        .descendant(
          of: find.byType(ScheduleWeekTimetable),
          matching: find.textContaining('김민수'),
        )
        .first;
    final Element before = tester.element(block);

    clock.now = clock.now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));

    expect(
      identical(tester.element(block), before),
      isTrue,
      reason: '선만 다시 그려져야 한다',
    );
  });

  testWidgets('타이머는 위젯이 사라질 때 함께 멈춘다', (tester) async {
    // 남아 있으면 `flutter_test` 가 "A Timer is still pending" 으로 이 테스트를
    // 깨뜨린다 — 통과하는 것 자체가 확인이다. 시계를 넘기지 않고 실제 `nowKst`
    // 로 도는 경로도 함께 지난다.
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );
    expect(find.byType(ScheduleWeekTimetable), findsOneWidget);

    // 스케줄 탭을 떠나면 시간표와 함께 선도 헐린다.
    await goTo(tester, AppRoutes.dashboard);
    expect(find.byType(ScheduleWeekTimetable), findsNothing);
  });
}
