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

/// 탄단지 누적 막대가 **어떤 하루에도** 사실만 말하는지. (#956)
///
/// 시드는 늘 셋이 다 있고 합계도 맞는 하루를 준다. 실서버 값은 음식 DB 에서
/// 오므로 그렇지 않다 — 탄수화물만 적힌 날도, 하루 칼로리와 탄단지 합계가
/// 어긋나는 날도, 영양이 아예 없는 날도 온다.
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

  /// 첫 칸 구간들의 색과 그려진 높이.
  List<(Color, double)> segmentsOf(WidgetTester tester) => <(Color, double)>[
    for (final Element e
        in find
            .descendant(
              of: find.byKey(const Key('diet-period-bar-0')),
              matching: find.byType(ColoredBox),
            )
            .evaluate())
      (
        (e.widget as ColoredBox).color,
        (e.renderObject! as RenderBox).size.height,
      ),
  ];

  testWidgets('칼로리와 탄단지 합계가 어긋나면 나머지가 남는다', (WidgetTester tester) async {
    // 탄 100g(400) + 단 50g(200) + 지 20g(180) = 780kcal 인데 하루는 1,560kcal.
    // 세 색이 막대를 꽉 채우면 없는 기여분을 지어내는 셈이다.
    await openMonth(
      tester,
      _day(calories: 1560, carbsG: 100, proteinG: 50, fatG: 20),
    );

    final List<(Color, double)> segments = segmentsOf(tester);
    final double total = segments.fold<double>(
      0,
      (double a, (Color, double) s) => a + s.$2,
    );

    final Iterable<(Color, double)> rest = segments.where(
      ((Color, double) s) => s.$1 == FigmaColors.track,
    );
    expect(rest, hasLength(1), reason: '설명되지 않는 칼로리가 자리를 차지해야 한다');
    expect(rest.single.$2 / total, closeTo((1560 - 780) / 1560, 0.03));

    // 탄수화물은 400/1560 만큼만 차지한다 — 780 을 분모로 잡으면 0.51 이 된다.
    final (Color, double) carbs = segments.firstWhere(
      ((Color, double) s) => s.$1 == FigmaColors.macroCarbs,
    );
    expect(carbs.$2 / total, closeTo(400 / 1560, 0.03));
  });

  testWidgets('탄단지 합계가 칼로리를 넘으면 나머지 없이 꽉 찬다', (WidgetTester tester) async {
    // 음수 나머지는 그릴 수 없으므로 탄단지 합계에 맞춰 채운다.
    await openMonth(
      tester,
      _day(calories: 500, carbsG: 200, proteinG: 100, fatG: 40),
    );

    final List<(Color, double)> segments = segmentsOf(tester);
    expect(
      segments.where(((Color, double) s) => s.$1 == FigmaColors.track),
      isEmpty,
    );
    expect(segments, hasLength(3));
  });

  testWidgets('탄수화물만 있는 날도 막대가 그려진다', (WidgetTester tester) async {
    // `hasMacros` 는 셋 중 하나만 양수여도 참이다. 0 인 성분까지 구간을 만들면
    // 아무것도 안 보이는 칸이 섞인다.
    await openMonth(tester, _day(calories: 800, carbsG: 200));

    final List<(Color, double)> segments = segmentsOf(tester);
    expect(segments, hasLength(1), reason: '0 인 성분은 구간을 만들지 않는다');
    expect(segments.single.$1, FigmaColors.macroCarbs);
    expect(segments.single.$2, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('아주 적게 먹은 성분도 실오라기로 남는다', (WidgetTester tester) async {
    // 반올림으로 셋이 모두 0 이 되면 높이만 있고 아무것도 그려지지 않은 막대가
    // 남는다 — #947 과 같은 종류의 사라짐이다.
    await openMonth(
      tester,
      _day(calories: 2000, carbsG: 0.05, proteinG: 0.05, fatG: 0.05),
    );

    for (final (Color _, double h) in segmentsOf(tester)) {
      expect(h, greaterThan(0));
    }
    expect(tester.takeException(), isNull);
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
