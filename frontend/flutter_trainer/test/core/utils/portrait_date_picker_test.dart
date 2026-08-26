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

  testWidgets('공용 날짜 선택기는 닫기 아이콘·입력창·달력·취소·확인을 모두 보인다', (
    WidgetTester tester,
  ) async {
    await openPicker(tester);

    final Finder dialog = find.byKey(const Key('portraitDatePicker'));
    expect(dialog, findsOneWidget);

    expect(
      find.descendant(of: dialog, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    // 전환 없이 입력창과 달력이 항상 같이 보인다.
    expect(find.byKey(const Key('portraitDatePickerInput')), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byKey(const Key('portraitDatePickerCancel')), findsOneWidget);
    expect(find.byKey(const Key('portraitDatePickerConfirm')), findsOneWidget);
  });

  testWidgets('달력에서 날짜를 고르면 입력창 글자도 같이 바뀐다', (WidgetTester tester) async {
    await openPicker(tester);

    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(
      find.byKey(const Key('portraitDatePickerInput')),
    );
    expect(field.controller!.text, contains('30'));
  });

  testWidgets('입력창에 유효한 날짜를 타이핑하면 달력도 그 날짜로 움직인다', (WidgetTester tester) async {
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

    await tester.enterText(
      find.byKey(const Key('portraitDatePickerInput')),
      '8/30/2026',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('portraitDatePickerConfirm')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 8, 30));
  });

  testWidgets('입력창에 범위 밖 날짜를 타이핑하면 오류를 보여주고 확인을 막는다', (
    WidgetTester tester,
  ) async {
    await openPicker(tester);

    await tester.enterText(
      find.byKey(const Key('portraitDatePickerInput')),
      '1/1/2020',
    );
    await tester.pumpAndSettle();

    final MaterialLocalizations l = MaterialLocalizations.of(
      tester.element(find.byKey(const Key('portraitDatePicker'))),
    );
    expect(find.text(l.dateOutOfRangeLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('portraitDatePickerConfirm')));
    await tester.pumpAndSettle();

    // 다이얼로그가 열려 있어야 한다 — 확인이 막혔다.
    expect(find.byKey(const Key('portraitDatePicker')), findsOneWidget);
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
