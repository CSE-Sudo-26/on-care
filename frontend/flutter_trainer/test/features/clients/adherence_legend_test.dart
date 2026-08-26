/// 주간 이행률 안내는 목록 위에 한 번만. (#1464)
///
/// 카드마다 같은 문구를 되풀이하면 목록의 정보 밀도가 낮아지고, 고객끼리 값을
/// 견주기 어렵다. 카드에는 값(%)과 그래프만 남기고, 그 그래프가 무엇인지는
/// 필터·정렬 줄이 한 번만 말한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> openClients(
    WidgetTester tester, {
    Size size = const Size(1600, 1200),
    double textScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.clients,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('안내는 툴바에 한 번만 있고 카드에는 없다', (tester) async {
    await openClients(tester);

    expect(
      find.byKey(const ValueKey<String>('clients-adherence-legend')),
      findsOneWidget,
    );
    // 카드가 여럿이어도 문구는 하나뿐이다.
    expect(find.byType(ClientCard), findsWidgets);
    expect(find.text('주간 이행률'), findsOneWidget);
    // 옛 용어는 화면 어디에도 없다.
    expect(find.text('주간 루틴 이행률'), findsNothing);
  });

  testWidgets('카드에는 값과 그래프가 남는다', (tester) async {
    await openClients(tester);

    // 값(%)과 막대는 고객마다 하나씩.
    final Finder values = find.byWidgetPredicate(
      (Widget w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'client-adherence-value-',
          ),
    );
    final Finder bars = find.byWidgetPredicate(
      (Widget w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'client-weekly-adherence-',
          ),
    );
    expect(values, findsWidgets);
    expect(bars, findsWidgets);
    expect(values.evaluate().length, bars.evaluate().length);
  });

  testWidgets('그래프는 스크린 리더에 주간 이행률과 값으로 읽힌다', (tester) async {
    await openClients(tester);

    final SemanticsNode node = tester.getSemantics(
      find
          .ancestor(
            of: find.byWidgetPredicate(
              (Widget w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'client-weekly-adherence-',
                  ),
            ),
            matching: find.byType(Semantics),
          )
          .first,
    );

    expect(node.label, contains('주간 이행률'));
    expect(node.value, isNotEmpty);
  });

  testWidgets('좁은 화면·큰 배율에서도 툴바가 겹치지 않는다', (tester) async {
    await openClients(tester, size: const Size(720, 1200), textScale: 1.4);

    expect(
      find.byKey(const ValueKey<String>('clients-adherence-legend')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
