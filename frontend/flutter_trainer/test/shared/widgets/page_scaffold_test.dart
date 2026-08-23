import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/page_scroll_reset.dart';

void main() {
  testWidgets('navigation reset returns the active page to the top', (
    tester,
  ) async {
    final reset = ValueNotifier<int>(0);
    addTearDown(reset.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageScrollResetScope(
            notifier: reset,
            child: const PageScaffold(
              title: 'Page',
              child: SizedBox(height: 1600),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(SingleChildScrollView);
    final scrollState = tester.state<ScrollableState>(
      find.descendant(of: scrollable, matching: find.byType(Scrollable)),
    );
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump();
    expect(scrollState.position.pixels, greaterThan(0));

    reset.value++;
    await tester.pump();

    expect(scrollState.position.pixels, 0);
  });

  testWidgets('navigation reset ignores a scrollable that was unmounted', (
    tester,
  ) async {
    final reset = ValueNotifier<int>(0);
    final showScrollable = ValueNotifier<bool>(true);
    addTearDown(reset.dispose);
    addTearDown(showScrollable.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageScrollResetScope(
            notifier: reset,
            child: ValueListenableBuilder<bool>(
              valueListenable: showScrollable,
              builder: (context, show, _) => PageScaffold(
                title: 'Page',
                scrollable: show,
                child: SizedBox(height: show ? 1600 : 100),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pump();

    showScrollable.value = false;
    await tester.pump();
    reset.value++;
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  for (final scrollable in <bool>[true, false]) {
    testWidgets('header and body share the same wide-screen alignment '
        'when scrollable is $scrollable', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageScaffold(
              title: '정렬 기준',
              scrollable: scrollable,
              child: Container(
                key: const ValueKey<String>('page-body-edge'),
                width: double.infinity,
                height: scrollable ? 120 : null,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      final headerLeft = tester.getTopLeft(find.text('정렬 기준')).dx;
      final bodyLeft = tester
          .getTopLeft(find.byKey(const ValueKey<String>('page-body-edge')))
          .dx;
      expect(bodyLeft, headerLeft);
    });
  }
}
