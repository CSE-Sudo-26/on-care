import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';

import '../../helpers/pump_app.dart';

/// 트레이너도 고객 식단을 `오늘 / 이번 주 / 이번 달` 로 본다. (#914)
///
/// 회원은 자기 앱에서 이미 세 기간을 골라 보는데, 정작 코칭하는 트레이너는
/// 오늘 하루밖에 못 봤다 — 회원이 "이번 주는 좀 과했어요" 라고 말해도 견줄
/// 화면이 없었다.
void main() {
  group('ClientDietPeriod', () {
    ClientDietPeriod periodOf(List<ClientDietDay> days) => ClientDietPeriod(
      range: (from: days.first.date, to: days.last.date),
      days: days,
    );

    test('평균은 기록이 있는 날만으로 나눈다', () {
      final period = periodOf(<ClientDietDay>[
        ClientDietDay(
          date: DateTime(2026, 8, 17),
          calories: 2000,
          sodiumMg: 1800,
          sugarG: 20,
        ),
        // 아직 오지 않은 날 / 적지 않은 날. 이 0 까지 나누면 달 초에는 평균이
        // 늘 실제보다 낮게 나온다.
        ClientDietDay(date: DateTime(2026, 8, 18)),
        ClientDietDay(
          date: DateTime(2026, 8, 19),
          calories: 2400,
          sodiumMg: 2200,
          sugarG: 30,
        ),
      ]);

      expect(period.loggedDays, 2);
      expect(period.avgCalories, 2200);
      expect(period.avgSodiumMg, 2000);
      expect(period.avgSugarG, 25);
      expect(period.isEmpty, isFalse);
    });

    test('기록이 하나도 없으면 비어 있다고 보고 0 으로 나누지 않는다', () {
      final period = periodOf(<ClientDietDay>[
        ClientDietDay(date: DateTime(2026, 8, 17)),
        ClientDietDay(date: DateTime(2026, 8, 18)),
      ]);

      expect(period.isEmpty, isTrue);
      expect(period.loggedDays, 0);
      expect(period.avgCalories, 0);
    });
  });

  group('DietView 기간 토글', () {
    testWidgets('오늘로 열리고, 이번 주를 고르면 영양 추이로 바뀐다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'diet'),
      );
      await tester.pumpAndSettle();

      // 기본은 오늘 — 지금까지 보던 화면이 그대로 첫 화면이다.
      expect(
        find.byKey(const Key('client-nutrition-summary-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('client-period-toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('client-diet-period-card')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('client-period-week')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('client-diet-period-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('client-nutrition-summary-card')),
        findsNothing,
      );
      // 토글은 카드 제목 줄에 그대로 남아, 되돌아갈 길이 사라지지 않는다.
      expect(
        find.byKey(const ValueKey<String>('client-period-toggle')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('client-period-month')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('client-diet-period-card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('client-period-today')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('client-nutrition-summary-card')),
        findsOneWidget,
      );
    });
  });
}
