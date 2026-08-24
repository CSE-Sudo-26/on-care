import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ReservationSlotsSheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.schedule,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('schedule-open-slots')),
      );
      await settle(tester);
    }

    testWidgets('opens on the currently selected day by default', (
      tester,
    ) async {
      await openSheet(tester);

      final today = todayKst();
      expect(
        find.text('${today.month}월 ${today.day}일'),
        findsWidgets, // 안내 문구와 날짜 버튼 둘 다 같은 표기를 쓴다.
      );
    });

    testWidgets('날짜 버튼을 누르면 과거로는 못 가는 날짜 선택창이 뜬다 (#1090)', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey<String>('slot-date')));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('시간 범위는 한 필드에 보이고 시 선택 뒤 단계 화살표가 나타난다', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.textContaining('10:00 – 11:00'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('slot-time-range')),
      );
      await settle(tester);

      expect(find.byType(TextField), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey<String>('time-range-back')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey<String>('clock-value-10')));
      await settle(tester);
      expect(
        find.byKey(const ValueKey<String>('time-range-back')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('time-range-next')),
        findsOneWidget,
      );
    });
  });
}
