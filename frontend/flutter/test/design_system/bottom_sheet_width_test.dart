import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/design_system/theme/app_theme.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';

void main() {
  testWidgets(
    'modal bottom sheet is capped at contentMaxWidth on a desktop viewport',
    (WidgetTester tester) async {
      // Wide desktop surface — far wider than contentMaxWidth (720).
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      showModalBottomSheet<void>(
        context: tester.element(find.byType(Scaffold)),
        // A full-width child collapses to whatever the route allows, so its
        // measured width is exactly the effective route-level cap.
        builder: (_) => const SizedBox(
          key: Key('sheetContent'),
          width: double.infinity,
          height: 200,
          child: Text('sheet'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsOneWidget);

      // Material 3 caps modal sheets at 640dp by default; the theme lifts that
      // route-level cap to contentMaxWidth (720). Asserting the exact width
      // proves the sheet neither spans the 1400 viewport nor stays at 640.
      final double sheetWidth =
          tester.getSize(find.byKey(const Key('sheetContent'))).width;
      expect(sheetWidth, AppBreakpoints.contentMaxWidth);
    },
  );
}
