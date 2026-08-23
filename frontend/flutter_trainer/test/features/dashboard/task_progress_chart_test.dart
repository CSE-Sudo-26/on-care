import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/features/dashboard/data/daily_task_progress_store.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/task_progress_chart.dart';

void main() {
  testWidgets('percent labels sit above and rise with their stacked bars', (
    tester,
  ) async {
    const snapshots = <DailyTaskSnapshot?>[
      DailyTaskSnapshot(
        total: 10,
        completedToday: 1,
        completedCarriedOver: 0,
        pendingKeys: <String>{},
      ),
      DailyTaskSnapshot(
        total: 10,
        completedToday: 3,
        completedCarriedOver: 2,
        pendingKeys: <String>{},
      ),
      DailyTaskSnapshot(
        total: 10,
        completedToday: 6,
        completedCarriedOver: 4,
        pendingKeys: <String>{},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: TaskProgressChart(
              snapshots: snapshots,
              dates: <DateTime>[
                DateTime(2026, 8, 24),
                DateTime(2026, 8, 25),
                DateTime(2026, 8, 26),
              ],
              labels: const <String>['월', '화', '수'],
              todayIndex: 2,
            ),
          ),
        ),
      ),
    );

    final labelRects = <Rect>[
      for (var i = 0; i < snapshots.length; i++)
        tester.getRect(
          find.byKey(ValueKey<String>('task-progress-percent-$i')),
        ),
    ];
    final barRects = <Rect>[
      for (var i = 0; i < snapshots.length; i++)
        tester.getRect(find.byKey(ValueKey<String>('task-progress-bar-$i'))),
    ];

    for (var i = 0; i < snapshots.length; i++) {
      expect(labelRects[i].bottom, lessThanOrEqualTo(barRects[i].top));
    }
    expect(labelRects[1].top, lessThan(labelRects[0].top));
    expect(labelRects[2].top, lessThan(labelRects[1].top));
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}
