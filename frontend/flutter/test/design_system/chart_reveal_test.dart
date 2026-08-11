import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/tokens/motion.dart';

/// Renders [ChartReveal] and records every progress value it hands the
/// builder, so tests can assert on the shape of the reveal rather than on
/// pixels.
Widget _harness({
  required List<double> log,
  Object? replayKey,
  Curve curve = Curves.linear,
  bool disableAnimations = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ChartReveal(
        replayKey: replayKey,
        curve: curve,
        duration: const Duration(milliseconds: 400),
        builder: (BuildContext context, double t) {
          log.add(t);
          return const SizedBox(width: 10, height: 10);
        },
      ),
    ),
  );
}

void main() {
  group('ChartReveal', () {
    testWidgets('runs progress from 0 to 1 over the reveal', (
      WidgetTester tester,
    ) async {
      final List<double> log = <double>[];
      await tester.pumpWidget(_harness(log: log));

      expect(log.first, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(log.last, greaterThan(0));
      expect(log.last, lessThan(1));

      await tester.pumpAndSettle();
      expect(log.last, 1);
    });

    testWidgets('renders the final state immediately when animations are off', (
      WidgetTester tester,
    ) async {
      final List<double> log = <double>[];
      await tester.pumpWidget(_harness(log: log, disableAnimations: true));

      // No tween at all — the builder is called once with the end value, so
      // reduced-motion users (and golden tests) see the finished chart.
      expect(log, <double>[1]);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('replays from 0 when replayKey changes', (
      WidgetTester tester,
    ) async {
      final List<double> log = <double>[];
      await tester.pumpWidget(_harness(log: log, replayKey: 'week'));
      await tester.pumpAndSettle();
      expect(log.last, 1);

      log.clear();
      await tester.pumpWidget(_harness(log: log, replayKey: 'month'));
      expect(log.first, 0);

      await tester.pumpAndSettle();
      expect(log.last, 1);
    });

    testWidgets(
      'keeps running without restarting when replayKey is unchanged',
      (WidgetTester tester) async {
        final List<double> log = <double>[];
        await tester.pumpWidget(_harness(log: log, replayKey: 'week'));
        await tester.pumpAndSettle();

        log.clear();
        await tester.pumpWidget(_harness(log: log, replayKey: 'week'));
        await tester.pump();
        expect(log.every((double t) => t == 1), isTrue);
      },
    );
  });

  group('chartStagger', () {
    test('leaves the first item leading and the last item trailing', () {
      // Halfway through the master timeline the left-most bar is further
      // along than the right-most one — that offset is the ripple.
      final double first = chartStagger(0.5, 0, 7);
      final double last = chartStagger(0.5, 6, 7);
      expect(first, greaterThan(last));
    });

    test('every item starts at 0 and finishes at 1', () {
      for (int i = 0; i < 7; i++) {
        expect(chartStagger(0, i, 7), 0);
        expect(chartStagger(1, i, 7), 1);
      }
    });

    test('a single item just follows the master progress', () {
      expect(chartStagger(0.5, 0, 1), AppMotion.chartCurve.transform(0.5));
    });

    test('clamps progress outside 0..1', () {
      expect(chartStagger(-1, 3, 7), 0);
      expect(chartStagger(2, 3, 7), 1);
    });
  });
}
