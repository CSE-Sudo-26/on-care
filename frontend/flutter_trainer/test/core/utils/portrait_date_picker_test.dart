import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/core/utils/portrait_date_picker.dart';

void main() {
  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showPortraitDatePicker(
              context: context,
              initialDate: DateTime(2026, 8, 24),
              firstDate: DateTime(2026),
              lastDate: DateTime(2027),
            ),
            child: const Text('달력 열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('달력 열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('공용 날짜 선택기는 닫기 아이콘과 취소·확인 버튼, 그리드 모드를 모두 보인다', (
    WidgetTester tester,
  ) async {
    await openPicker(tester);

    final Finder dialog = find.byKey(const Key('portraitDatePicker'));
    expect(dialog, findsOneWidget);

    expect(
      find.descendant(of: dialog, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('portraitDatePickerCancel')), findsOneWidget);
    expect(find.byKey(const Key('portraitDatePickerConfirm')), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.byType(CalendarDatePicker)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.byIcon(Icons.edit)),
      findsOneWidget,
    );
  });

  testWidgets('연필 아이콘을 누르면 키보드 입력 모드로, 다시 누르면 그리드로 돌아간다', (
    WidgetTester tester,
  ) async {
    await openPicker(tester);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.byType(InputDatePickerFormField), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(InputDatePickerFormField), findsNothing);
  });

  testWidgets('키보드 입력 모드에서 날짜를 타이핑하고 확인하면 그 날짜를 돌려준다', (
    WidgetTester tester,
  ) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showPortraitDatePicker(
                context: context,
                initialDate: DateTime(2026, 8, 24),
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
              );
            },
            child: const Text('달력 열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('달력 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '08/30/2026');
    await tester.tap(find.byKey(const Key('portraitDatePickerConfirm')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 8, 30));
  });

  testWidgets('우측 상단 X 를 누르면 아무 값 없이 닫힌다', (WidgetTester tester) async {
    DateTime? result = DateTime(1999);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showPortraitDatePicker(
                context: context,
                initialDate: DateTime(2026, 8, 24),
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
              );
            },
            child: const Text('달력 열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('달력 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('취소를 누르면 아무 값 없이 닫힌다', (WidgetTester tester) async {
    DateTime? result = DateTime(1999);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showPortraitDatePicker(
                context: context,
                initialDate: DateTime(2026, 8, 24),
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
              );
            },
            child: const Text('달력 열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('달력 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portraitDatePickerCancel')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('확인을 누르면 고른 날짜를 돌려준다', (WidgetTester tester) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showPortraitDatePicker(
                context: context,
                initialDate: DateTime(2026, 8, 24),
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
              );
            },
            child: const Text('달력 열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('달력 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portraitDatePickerConfirm')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 8, 24));
  });
}
