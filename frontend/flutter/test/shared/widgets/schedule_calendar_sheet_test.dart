import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:oncare/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// 일정 없는 달력만 본다 — 이 테스트가 확인하는 것은 **몇 칸이 그려지는가**이지
/// 칸 안의 일정이 아니다.
class _EmptyScheduleRepository implements ScheduleRepository {
  @override
  Future<List<ScheduleEvent>> fetchByDate(String date) async =>
      const <ScheduleEvent>[];

  @override
  Future<List<ScheduleEvent>> fetchByMonth(String month) async =>
      const <ScheduleEvent>[];

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
Widget _app({required DateTime initialDate}) {
  return ProviderScope(
    overrides: <Override>[
      scheduleRepositoryProvider.overrideWithValue(_EmptyScheduleRepository()),
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

Future<void> _openSheet(WidgetTester tester, DateTime initialDate) async {
  await tester.pumpWidget(_app(initialDate: initialDate));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

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
  });

  testWidgets('세로가 짧으면 잘라내지 않고 스크롤해서 말일에 닿는다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(tester, august2026);

    await tester.scrollUntilVisible(
      find.byKey(const Key('calendar-day-31')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('calendar-day-31')), findsOneWidget);
  });

  testWidgets('말일이 토요일이 아닌 달도 마지막 주가 7칸으로 닫힌다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 2026-09: 1일 화요일 → 선행 2칸 + 30일 = 32칸, 후행 채움 3칸 = 35칸(5주).
    await _openSheet(tester, DateTime(2026, 9, 10));

    final GridView grid = tester.widget<GridView>(find.byType(GridView));
    final SliverChildBuilderDelegate delegate =
        grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 35);
    expect(find.byKey(const Key('calendar-day-30')), findsOneWidget);
  });
}
