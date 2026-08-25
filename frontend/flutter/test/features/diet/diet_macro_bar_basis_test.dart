import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../helpers/fake_diet_repository.dart';

/// 기간 그래프의 칼로리 막대가 **어떤 하루에도** 사실만 말하는지. (#956, #1427)
///
/// 한때 이 막대는 탄단지 농담으로 쌓았다(#956 은 그 분모를 다룬 이슈다).
/// 지금은 한 색이다 — 막대에서 탄·단·지 수치를 읽을 수 없는데 색만 셋으로
/// 갈라져 있어, 구성까지 정확히 말해 주는 그림처럼 보였기 때문이다(#1427).
/// 탄단지는 카드 머리의 상세가 숫자와 함께 말한다.
///
/// 실서버 값은 음식 DB 에서 온다 — 탄수화물만 적힌 날도, 하루 칼로리와 탄단지
/// 합계가 어긋나는 날도, 영양이 아예 없는 날도 온다. 어느 쪽이든 막대는
/// 총칼로리 하나만 말해야 한다.
class _FixedDietRepository extends FakeDietRepository {
  _FixedDietRepository(this.day);

  final DietDay day;

  @override
  Future<DietDay> fetchByDate(DateTime date) async => day;

  @override
  Future<DietDay> fetchToday() async => day;
}

/// 하루 합계만 들고 있는 [DietDay] — 실서버 응답의 모양이다(음식 배열에는
/// 이름과 칼로리만 들어 있어, 영양은 하루/끼니 단위로만 온다).
DietDay _day({
  required int calories,
  double carbsG = 0,
  double proteinG = 0,
  double fatG = 0,
}) => DietDay(
  entries: <DietEntry>[
    DietEntry(
      id: 'e',
      mealType: MealType.lunch,
      timeLabel: '12:00',
      foods: const <FoodItem>[],
      totalCalories: calories,
      sodiumMg: 900,
      sugarG: 8,
      carbsG: carbsG,
      proteinG: proteinG,
      fatG: fatG,
    ),
  ],
  totalCalories: calories,
  totalSodiumMg: 900,
  totalSugarG: 8,
  macros: DietMacros(
    carbsPct: 0,
    proteinPct: 0,
    fatPct: 0,
    carbsG: carbsG,
    proteinG: proteinG,
    fatG: fatG,
  ),
  aiCoachMessage: '',
);

void main() {
  Future<void> openMonth(WidgetTester tester, DietDay day) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(_FixedDietRepository(day)),
          accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DietRecordPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diet-period-tab-month')));
    await tester.pumpAndSettle();
  }

  /// 첫 칸 막대에 칠해진 색. 한 색 막대라 `Container` 의 배경이 곧 그 색이다.
  Color? barColorOf(WidgetTester tester) {
    final Container box = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('diet-period-bar-0')),
            matching: find.byType(Container),
          )
          .first,
    );
    return (box.decoration! as BoxDecoration).color;
  }

  /// 막대 안에 쌓인 구간. 쌓지 않으므로 언제나 비어 있어야 한다.
  Iterable<Element> segmentsOf(WidgetTester tester) => find
      .descendant(
        of: find.byKey(const Key('diet-period-bar-0')),
        matching: find.byType(ColoredBox),
      )
      .evaluate();

  testWidgets('탄단지가 다 있는 날도 막대는 회색 한 색이다', (WidgetTester tester) async {
    await openMonth(
      tester,
      _day(calories: 1560, carbsG: 200, proteinG: 100, fatG: 40),
    );

    expect(segmentsOf(tester), isEmpty, reason: '막대를 셋으로 쌓지 않는다');
    expect(barColorOf(tester), FigmaColors.barNeutral.withValues(alpha: 0.85));
  });

  testWidgets('칼로리와 탄단지 합계가 어긋나도 막대는 총칼로리만 말한다', (
    WidgetTester tester,
  ) async {
    // 탄 100g(400) + 단 50g(200) + 지 20g(180) = 780kcal 인데 하루는 1,560kcal.
    // 쌓던 시절에는 이 어긋남이 분모 문제였다(#956) — 이제는 그릴 구간 자체가
    // 없으므로 막대는 1,560kcal 높이 하나다.
    await openMonth(
      tester,
      _day(calories: 1560, carbsG: 100, proteinG: 50, fatG: 20),
    );

    expect(segmentsOf(tester), isEmpty);
    expect(barColorOf(tester), FigmaColors.barNeutral.withValues(alpha: 0.85));
  });

  testWidgets('탄수화물만 있는 날도 같은 회색 막대다', (WidgetTester tester) async {
    await openMonth(tester, _day(calories: 800, carbsG: 200));

    expect(segmentsOf(tester), isEmpty);
    expect(barColorOf(tester), FigmaColors.barNeutral.withValues(alpha: 0.85));
    expect(tester.takeException(), isNull);
  });

  testWidgets('영양이 아예 없는 날도 같은 회색 막대다', (WidgetTester tester) async {
    await openMonth(tester, _day(calories: 1500));

    expect(segmentsOf(tester), isEmpty);
    expect(barColorOf(tester), FigmaColors.barNeutral.withValues(alpha: 0.85));
  });

  testWidgets('영양이 하나도 없는 기간에는 탄단지 범례가 없다', (WidgetTester tester) async {
    // 칼로리 지표에서는 `days` 가 언제나 넘어간다. 범례까지 늘 그리면 한 색
    // 막대에 3색 범례가 붙어 막대 색의 뜻을 잘못 설명한다.
    await openMonth(tester, _day(calories: 1500));

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(DietRecordPage)),
    );
    expect(find.byKey(const Key('diet-period-bar-0')), findsOneWidget);
    expect(find.text(l.homeMacroCarbs), findsNothing);
    expect(find.text(l.homeMacroProtein), findsNothing);
    expect(find.text(l.homeMacroFat), findsNothing);
  });

  testWidgets('영양이 있는 기간에는 범례가 보인다', (WidgetTester tester) async {
    await openMonth(
      tester,
      _day(calories: 1560, carbsG: 200, proteinG: 100, fatG: 40),
    );

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(DietRecordPage)),
    );
    expect(find.text(l.homeMacroCarbs), findsWidgets);
    expect(find.text(l.homeMacroProtein), findsWidgets);
    expect(find.text(l.homeMacroFat), findsWidgets);
  });
}
