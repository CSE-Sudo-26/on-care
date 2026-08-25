import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 프로그램 직접 만들기의 PT 등록 날짜·시각 선택 UI. (#1425)
///
/// 이 흐름만 기본 Material `showDatePicker`·`showTimePicker` 를 썼다. 앱의 다른
/// 입력 화면은 세로형 달력(`showPortraitDatePicker`)과 스케줄 탭의 시계
/// 선택기를 쓴다 — 같은 앱에서 날짜·시각을 고르는 방법이 탭마다 다르면 공통
/// 검증·접근성 개선도 함께 가지 않는다.
void main() {
  DateTime today() {
    final now = nowKst();
    return DateTime(now.year, now.month, now.day);
  }

  /// 워크스페이스만 띄운다 — 등록 날짜·시각은 이 위젯이 쥔다.
  Future<({DateTime date, TimeOfDay start, TimeOfDay end}) Function()>
  pumpWorkspace(
    WidgetTester tester, {
    Size size = const Size(1400, 1000),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DateTime date = today();
    TimeOfDay start = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 11, minute: 0);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: ProgramEditorWorkspace(
                clientGoal: '체지방 감량',
                aiSuggestions: const <AiRoutineItem>[],
                registerDate: date,
                registerStartTime: start,
                registerEndTime: end,
                onRegisterDateChanged: (value) => setState(() => date = value),
                onRegisterTimeRangeChanged: (value) => setState(() {
                  start = value.start;
                  end = value.end;
                }),
                onSend: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => (date: date, start: start, end: end);
  }

  Future<void> tapChip(WidgetTester tester, String key) async {
    final chip = find.byKey(ValueKey<String>(key));
    await tester.scrollUntilVisible(
      chip,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('기본값은 오늘·오전 10시–11시이고 칩에 그대로 보인다', (tester) async {
    final read = await pumpWorkspace(tester);

    expect(read().date, today());
    expect(read().start, const TimeOfDay(hour: 10, minute: 0));
    expect(read().end, const TimeOfDay(hour: 11, minute: 0));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('program-register-date')),
        matching: find.text(ymd(today())),
      ),
      findsOneWidget,
    );
  });

  testWidgets('날짜 선택은 넓은 창에서도 세로형 달력이다', (tester) async {
    await pumpWorkspace(tester);
    await tapChip(tester, 'program-register-date');

    expect(find.byType(DatePickerDialog), findsOneWidget);
    // 달력은 자기 화면이 가로로 넓으면 헤더와 그리드를 좌우로 나눈다.
    // `showPortraitDatePicker` 는 이 다이얼로그에게만 세로 화면을 넘겨 늘
    // 위아래로 선 달력이 되게 한다 — 트레이너 웹은 늘 넓은 창이다.
    final BuildContext dialogContext = tester.element(
      find.byType(DatePickerDialog),
    );
    expect(MediaQuery.of(dialogContext).orientation, Orientation.portrait);
  });

  testWidgets('과거 날짜는 고를 수 없고 한 해 앞까지 고른다', (tester) async {
    await pumpWorkspace(tester);
    await tapChip(tester, 'program-register-date');

    final DatePickerDialog dialog = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(dialog.firstDate, today());
    expect(dialog.lastDate, today().add(const Duration(days: 365)));
    expect(dialog.initialDate, today());
  });

  testWidgets('시각 선택은 스케줄 탭과 같은 범위 선택기다', (tester) async {
    final read = await pumpWorkspace(tester);
    await tapChip(tester, 'program-register-time');

    // Material 기본 시간 선택기가 아니라 스케줄 탭의 시계다.
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('session-time-range-start-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('session-time-range-confirm')),
      findsOneWidget,
    );

    // 시작을 9시 30분으로 고르고 확인한다.
    await tester.tap(find.byKey(const ValueKey<String>('clock-value-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('clock-value-30')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('session-time-range-confirm')),
    );
    await tester.pumpAndSettle();

    expect(read().start, const TimeOfDay(hour: 9, minute: 30));
    expect(read().end, const TimeOfDay(hour: 11, minute: 0));
  });

  testWidgets('시각 선택을 닫으면 값이 그대로다', (tester) async {
    final read = await pumpWorkspace(tester);
    await tapChip(tester, 'program-register-time');

    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();

    expect(read().start, const TimeOfDay(hour: 10, minute: 0));
    expect(read().end, const TimeOfDay(hour: 11, minute: 0));
  });
}
