/// 기간을 바꾸면 AI 맞춤 조언도 바뀐다. (#1017)
///
/// 예전에는 조언이 오늘 기준 하나뿐이라, 이번 주를 보고 있는데 "오늘 점심이
/// 짰어요" 를 읽게 됐다. 그래프만 갈아 끼우고 조언이 남으면 지금 화면과 무관한
/// 말이 되어 신뢰를 잃는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../helpers/fake_diet_repository.dart';

Widget _app() => ProviderScope(
  overrides: <Override>[
    dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
    accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
  ],
  child: const MaterialApp(
    locale: Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DietRecordPage(),
  ),
);

void main() {
  testWidgets('오늘 / 이번 주 / 전체가 각각 다른 조언을 보여 준다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    String advice() {
      final Finder card = find.byType(_adviceCardType(tester));
      return tester
          .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
          .map((Text t) => t.data ?? '')
          .join(' ');
    }

    final String today = advice();
    expect(today, isNotEmpty);

    await tester.tap(find.byKey(const Key('diet-period-tab-week')));
    await tester.pumpAndSettle();
    final String week = advice();
    expect(week, isNot(today), reason: '이번 주인데 오늘 조언이 그대로다');
    expect(week, contains('이번 주'));

    await tester.tap(find.byKey(const Key('diet-period-tab-month')));
    await tester.pumpAndSettle();
    final String all = advice();
    expect(all, isNot(week), reason: '전체인데 이번 주 조언이 그대로다');
  });
}

/// AI 조언 카드의 타입 — 위젯이 private 이라 화면에서 찾아 쓴다.
Type _adviceCardType(WidgetTester tester) => tester
    .widget(
      find
          .byWidgetPredicate(
            (Widget w) => w.runtimeType.toString() == '_AiFeedback',
          )
          .first,
    )
    .runtimeType;
