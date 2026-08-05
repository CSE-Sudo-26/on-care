import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';

void main() {
  Future<void> pumpChart(WidgetTester tester, {int? pendingFromIndex}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarSeriesChart(
            values: const <int>[100, 80, 60, 40, 20, 10, 5],
            labels: const <String>['월', '화', '수', '목', '금', '토', '일'],
            maxValue: 100,
            showValues: true,
            valueSuffix: '%',
            pendingFromIndex: pendingFromIndex,
          ),
        ),
      ),
    );
  }

  group('BarSeriesChart', () {
    testWidgets('prints every value when no day is pending', (tester) async {
      await pumpChart(tester);

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
    });

    testWidgets('days that have not happened print no value', (tester) async {
      // Shown on a Thursday: 금/토/일 are still ahead. Whatever the source
      // holds for them is not a result the member earned, so the chart
      // must not state it — a printed "20%" for Friday reads as a real,
      // bad Friday.
      await pumpChart(tester, pendingFromIndex: 4);

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('20%'), findsNothing);
      expect(find.text('10%'), findsNothing);
      expect(find.text('5%'), findsNothing);

      // The labels stay: the week is still Mon–Sun, those days just
      // haven't come round yet.
      expect(find.text('금'), findsOneWidget);
      expect(find.text('일'), findsOneWidget);
    });

    testWidgets('a pending day never takes the over-target colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BarSeriesChart(
              // Fri/Sat/Sun are over the threshold in the source data but
              // haven't happened; painting their track red would report a
              // bad day the member could not have had yet.
              values: const <int>[10, 10, 10, 10, 90, 90, 90],
              labels: const <String>['월', '화', '수', '목', '금', '토', '일'],
              maxValue: 100,
              overThreshold: 50,
              pendingFromIndex: 4,
            ),
          ),
        ),
      );

      final tracks = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toList();
      expect(tracks, isNot(contains(AppColors.overTarget)));
      expect(tracks.where((c) => c == AppColors.border).length, 3);
    });
  });
}
