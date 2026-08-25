import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/core/utils/portrait_date_picker.dart';

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

  testWidgets('공용 날짜 선택기는 흰 배경에 취소 텍스트 없이 닫기 아이콘과 확인 버튼만 보인다', (
    WidgetTester tester,
  ) async {
    await openPicker(tester);

    final Finder dialog = find.byKey(const Key('portraitDatePicker'));
    expect(dialog, findsOneWidget);
    expect(tester.widget<Dialog>(dialog).backgroundColor, Colors.white);

    // 하단 '취소' 텍스트 버튼이 없다 — 닫기는 우측 상단 X 하나로 충분하다.
    expect(find.text('취소'), findsNothing);
    expect(
      find.descendant(of: dialog, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('portraitDatePickerConfirm')),
      findsOneWidget,
    );
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
