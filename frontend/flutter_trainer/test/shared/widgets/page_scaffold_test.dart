import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';

void main() {
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
