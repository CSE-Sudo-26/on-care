import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/presentation/widgets/consult_time_range_picker.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

void main() {
  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showConsultTimeRangePicker(
              context: context,
              start: const TimeOfDay(hour: 10, minute: 0),
              end: const TimeOfDay(hour: 11, minute: 0),
            ),
            child: const Text('시간 선택 열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('시간 선택 열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('시작 시간 입력에 24시간 기준 값을 직접 타이핑할 수 있다', (WidgetTester tester) async {
    await openPicker(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('consult-time-range-start-input')),
      '23:30',
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.byKey(
              const ValueKey<String>('consult-time-range-start-input'),
            ),
          )
          .controller!
          .text,
      '23:30',
    );
  });

  testWidgets('종료 시간이 시작 시간보다 빠르면 확인을 막고 안내한다', (WidgetTester tester) async {
    await openPicker(tester);

    // 시작 시(10) → 시작 분(0) → 종료 시(9)까지 다이얼로 고른다.
    await tester.tap(
      find.byKey(const ValueKey<String>('consult-clock-value-10')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('consult-clock-value-0')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('consult-clock-value-9')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('consult-time-range-invalid-end')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('consult-time-range-confirm')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('확인을 누르면 고른 시작·종료 시각을 돌려준다', (WidgetTester tester) async {
    TimeRangeValue? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showConsultTimeRangePicker(
                context: context,
                start: const TimeOfDay(hour: 10, minute: 0),
                end: const TimeOfDay(hour: 11, minute: 0),
              );
            },
            child: const Text('시간 선택 열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('시간 선택 열기'));
    await tester.pumpAndSettle();

    final Finder confirm = find.byKey(
      const ValueKey<String>('consult-time-range-confirm'),
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(result, (
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
    ));
  });
}
