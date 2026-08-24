import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/core/utils/portrait_date_picker.dart';

void main() {
  testWidgets('공용 날짜 선택기는 흰 배경과 투명 surface tint를 사용한다', (
    WidgetTester tester,
  ) async {
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

    final BuildContext pickerContext = tester.element(
      find.byType(DatePickerDialog),
    );
    final DatePickerThemeData theme = DatePickerTheme.of(pickerContext);
    expect(theme.backgroundColor, Colors.white);
    expect(theme.headerBackgroundColor, Colors.white);
    expect(theme.surfaceTintColor, Colors.transparent);
  });
}
