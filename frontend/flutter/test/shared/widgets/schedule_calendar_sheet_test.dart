import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:oncare/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// 지정한 일정만 돌려주는 대역. 기본값은 빈 달 — 칸 수를 보는 테스트는
/// 칸 안의 일정에 좌우되지 않아야 한다.
class _EmptyScheduleRepository implements ScheduleRepository {
  _EmptyScheduleRepository([this.events = const <ScheduleEvent>[]]);

  final List<ScheduleEvent> events;

  @override
  Future<List<ScheduleEvent>> fetchByDate(String date) async =>
      const <ScheduleEvent>[];

  @override
  Future<List<ScheduleEvent>> fetchByMonth(String month) async => events;

  @override
  Future<ScheduleEvent> createEvent({
    required String date,
    required String title,
    String time = '',
    ScheduleCategory category = ScheduleCategory.other,
  }) async {
    throw UnimplementedError();
  }
}

/// 시트를 띄우는 버튼 하나짜리 화면.
Widget _app({
  required DateTime initialDate,
  List<ScheduleEvent> events = const <ScheduleEvent>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      scheduleRepositoryProvider.overrideWithValue(
        _EmptyScheduleRepository(events),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () =>
                showScheduleCalendarSheet(context, initialDate: initialDate),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(
  WidgetTester tester,
  DateTime initialDate, {
  List<ScheduleEvent> events = const <ScheduleEvent>[],
}) async {
  await tester.pumpWidget(_app(initialDate: initialDate, events: events));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

/// 달력 그리드가 그린 칸 수(선행 공백 + 날짜 + 후행 채움).
int _gridCellCount(WidgetTester tester) {
  final GridView grid = tester.widget<GridView>(find.byType(GridView));
  return (grid.childrenDelegate as SliverChildBuilderDelegate).childCount!;
}

/// 달력 그리드 **자신의** Scrollable. 화면에 다른 스크롤 뷰가 있어도 이것을
/// 집도록 GridView 밑에서 찾는다 — 엉뚱한 Scrollable 위에서 스크롤을 시험하면
/// 아무것도 검증하지 못한다.
Finder _calendarScrollable() => find
    .descendant(of: find.byType(GridView), matching: find.byType(Scrollable))
    .first;

void main() {
  // 2026-08 은 1일이 토요일이라 6주 그리드가 되는 달이다 — 선행 공백 6칸 +
  // 31일 = 37칸. 잘림 회귀(#669)가 가장 먼저 드러나는 모양.
  final DateTime august2026 = DateTime(2026, 8, 15);

  testWidgets('세로가 넉넉하면 6주짜리 달의 말일까지 한 화면에 그린다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(tester, august2026);

    expect(find.byKey(const Key('calendar-day-1')), findsOneWidget);
    expect(find.byKey(const Key('calendar-day-22')), findsOneWidget);
    // 예전 구현이 잘라 먹던 마지막 주.
    expect(find.byKey(const Key('calendar-day-31')), findsOneWidget);
    // 6주 × 7칸. 날짜 키만 보면 후행 채움 칸이 사라져도 통과하므로 칸 수까지
    // 못박는다 — 마지막 주 테두리가 닫히는 근거다.
    expect(_gridCellCount(tester), 42);
  });

  testWidgets('세로가 짧으면 잘라내지 않고 스크롤해서 말일에 닿는다', (
    WidgetTester tester,
  ) async {
    // 이 높이라야 6주 그리드가 남은 공간을 넘어 실제로 스크롤이 생긴다.
    // 640 에서는 다 들어가 버려 스크롤 경로를 전혀 지나지 않는다.
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(tester, august2026);

    final ScrollableState grid = tester.state(_calendarScrollable());
    expect(
      grid.position.maxScrollExtent,
      greaterThan(0),
      reason: '잘라내는 대신 스크롤이 생겨야 한다',
    );
    // 스크롤하기 전에는 말일에 닿지 못한다 — 이 전제가 깨지면 아래 스크롤
    // 검증이 아무것도 확인하지 않게 된다.
    expect(find.byKey(const Key('calendar-day-31')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('calendar-day-31')),
      80,
      scrollable: _calendarScrollable(),
    );

    expect(grid.position.pixels, greaterThan(0));
    expect(find.byKey(const Key('calendar-day-31')), findsOneWidget);
    // 스크롤해도 칸 수는 그대로다(잘라낸 것이 아니라 밀려나 있을 뿐).
    expect(_gridCellCount(tester), 42);
  });

  testWidgets('말일이 토요일이 아닌 달도 마지막 주가 7칸으로 닫힌다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 2026-09: 1일 화요일 → 선행 2칸 + 30일 = 32칸, 후행 채움 3칸 = 35칸(5주).
    await _openSheet(tester, DateTime(2026, 9, 10));

    expect(_gridCellCount(tester), 35);
    expect(find.byKey(const Key('calendar-day-30')), findsOneWidget);
  });

  testWidgets('주가 딱 맞아떨어지는 달은 빈 줄을 덧붙이지 않는다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 2026-02: 1일 일요일 + 28일 → 선행 0칸·후행 0칸으로 정확히 4주.
    // 후행 계산의 바깥 `% 7` 이 빠지면 여기서 빈 한 줄이 더 붙는다.
    await _openSheet(tester, DateTime(2026, 2, 10));

    expect(_gridCellCount(tester), 28);
    expect(find.byKey(const Key('calendar-day-28')), findsOneWidget);
  });

  testWidgets('일정이 칸을 넘쳐도 오버플로 없이 날짜 숫자는 남는다', (WidgetTester tester) async {
    // 좁고 낮은 화면 + 한 날짜에 일정 6건 = 칸 높이를 확실히 넘긴다.
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(
      tester,
      august2026,
      events: <ScheduleEvent>[
        for (int i = 0; i < 6; i++)
          ScheduleEvent(
            id: 'e$i',
            date: '2026-08-03',
            time: '0$i:00',
            title: '일정 $i',
            category: ScheduleCategory.exercise,
          ),
      ],
    );

    expect(
      tester.takeException(),
      isNull,
      reason: '칩이 칸을 넘쳐도 오버플로 예외가 나면 안 된다',
    );
    expect(find.byKey(const Key('calendar-day-3')), findsOneWidget);
    // 칸 안에서 잘리더라도 첫 칩은 그려진다.
    expect(find.text('00:00 일정 0'), findsOneWidget);
  });
}
