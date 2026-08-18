import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../helpers/fake_diet_repository.dart';

Widget _app(Widget home, {List<Override> overrides = const <Override>[]}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _PastDateDietRepository extends FakeDietRepository {
  _PastDateDietRepository({this.fail = false});

  final bool fail;

  @override
  Future<DietDay> fetchByDate(DateTime date) async {
    if (fail) throw StateError('date lookup failed');
    return const DietDay(
      entries: <DietEntry>[
        DietEntry(
          id: 'past-meal',
          mealType: MealType.lunch,
          timeLabel: '12:00',
          foods: <FoodItem>[FoodItem(name: '과거 식사', calories: 420)],
          totalCalories: 420,
          sodiumMg: 350,
          sugarG: 7.5,
          carbsG: 40,
          proteinG: 20,
          fatG: 10,
        ),
      ],
      totalCalories: 420,
      totalSodiumMg: 350,
      totalSugarG: 7.5,
      macros: DietMacros(
        carbsPct: 49,
        proteinPct: 24,
        fatPct: 27,
        carbsG: 40,
        proteinG: 20,
        fatG: 10,
      ),
      aiCoachMessage: '선택한 날짜의 피드백',
    );
  }
}

Future<void> _selectDaysAgo(WidgetTester tester, [int days = 1]) async {
  final selectedDate = DateTime.now().subtract(Duration(days: days));
  await tester.tap(find.text('${selectedDate.day}'));
  await tester.pumpAndSettle();
}

void main() {
  test('mock account keeps updated health goals', () async {
    final MockAccountRepository repository = MockAccountRepository();

    await repository.updateHealthGoals(
      dailyCalories: 1800,
      dailySodiumMg: 1500,
      dailySugarG: 35,
      dailyCarbsG: 220,
      dailyProteinG: 120,
      dailyFatG: 50,
    );

    final UserProfile profile = await repository.fetchProfile();
    expect(profile.effectiveDailyCalories, 1800);
    expect(profile.effectiveDailySodiumMg, 1500);
    expect(profile.effectiveDailySugarG, 35);
    expect(profile.effectiveDailyCarbsG, 220);
    expect(profile.effectiveDailyProteinG, 120);
    expect(profile.effectiveDailyFatG, 50);
  });

  test('health goal fallback is applied independently per field', () {
    const UserProfile profile = UserProfile(
      id: 'member',
      name: '회원',
      email: 'member@example.com',
      dailyCalories: 1800,
      dailySodiumMg: 1500,
      dailySugarG: 35,
      dailyCarbsG: 220,
      dailyProteinG: 120,
      dailyFatG: 50,
    );
    expect(profile.effectiveDailyCalories, 1800);
    expect(profile.effectiveDailySodiumMg, 1500);
    expect(profile.effectiveDailySugarG, 35);
    expect(profile.effectiveDailyCarbsG, 220);
    expect(profile.effectiveDailyProteinG, 120);
    expect(profile.effectiveDailyFatG, 50);

    const UserProfile partial = UserProfile(
      id: 'member',
      name: '회원',
      email: 'member@example.com',
      dailyCalories: 1800,
    );
    expect(partial.effectiveDailyCalories, 1800);
    expect(partial.effectiveDailySodiumMg, 2000);
    expect(partial.effectiveDailySugarG, 50);
    expect(partial.effectiveDailyCarbsG, 275);
    expect(partial.effectiveDailyProteinG, 100);
    expect(partial.effectiveDailyFatG, 55);
  });

  testWidgets('nutrition summary uses all personal health goals', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DietDay day =
        await tester.runAsync(() => FakeDietRepository().fetchToday())
            as DietDay;
    const UserProfile profile = UserProfile(
      id: 'member',
      name: '회원',
      email: 'member@example.com',
      dailyCalories: 1800,
      dailySodiumMg: 1500,
      dailySugarG: 35,
      dailyCarbsG: 220,
      dailyProteinG: 120,
      dailyFatG: 50,
    );

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: NutritionSummary(day: day, profile: profile),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1,800 kcal'), findsOneWidget);
    expect(find.textContaining('/ 220g'), findsOneWidget);
    expect(find.textContaining('/ 120g'), findsOneWidget);
    expect(find.textContaining('/ 50g'), findsOneWidget);
    expect(find.textContaining('/ 1,500mg'), findsOneWidget);
    expect(find.textContaining('/ 35g'), findsOneWidget);
  });

  testWidgets(
    'nutrition summary highlights progress and status on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(340, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final DietDay day =
          await tester.runAsync(() => FakeDietRepository().fetchToday())
              as DietDay;

      await tester.pumpWidget(_app(Scaffold(body: NutritionSummary(day: day))));
      await tester.pumpAndSettle();

      final Finder summaryCard = find.byKey(
        const Key('nutrition-summary-card'),
      );
      expect(summaryCard, findsOneWidget);
      expect(
        find.byKey(const Key('nutrition-calorie-progress')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summaryCard,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('1,067'), findsOneWidget);
      expect(find.textContaining('2,000 kcal'), findsOneWidget);
      expect(find.textContaining('3,428'), findsOneWidget);
      expect(find.textContaining('17.8'), findsOneWidget);
      expect(find.text('목표 초과'), findsOneWidget);
      expect(find.text('정상'), findsOneWidget);
      expect(find.text('목표보다 1,428mg 많아요'), findsOneWidget);
      expect(find.text('목표까지 32.2g 남았어요'), findsOneWidget);
      expect(
        find.byKey(const Key('nutrition-status-vertical-progress-나트륨')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('nutrition-status-vertical-progress-당류')),
        findsOneWidget,
      );
      final List<ColoredBox> sodiumProgressColors = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byKey(
                const Key('nutrition-status-vertical-progress-나트륨'),
              ),
              matching: find.byType(ColoredBox),
            ),
          )
          .toList();
      final List<ColoredBox> sugarProgressColors = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byKey(
                const Key('nutrition-status-vertical-progress-당류'),
              ),
              matching: find.byType(ColoredBox),
            ),
          )
          .toList();
      expect(sodiumProgressColors.last.color, FigmaColors.dangerRed);
      expect(sugarProgressColors.last.color, FigmaColors.greenText);

      final Finder carbs = find.byKey(const Key('nutrition-macro-탄수화물'));
      final Finder protein = find.byKey(const Key('nutrition-macro-단백질'));
      final Finder fat = find.byKey(const Key('nutrition-macro-지방'));
      final Finder sodiumCard = find.byKey(
        const Key('nutrition-sodium-status'),
      );
      final Finder sugarCard = find.byKey(const Key('nutrition-sugar-status'));

      // 좁은 화면에서 각 항목이 겹치지 않고 세로로 쌓이는지 확인한다.
      expect(
        tester.getBottomLeft(carbs).dy,
        lessThan(tester.getTopLeft(protein).dy),
      );
      expect(
        tester.getBottomLeft(protein).dy,
        lessThan(tester.getTopLeft(fat).dy),
      );
      expect(
        tester.getBottomLeft(summaryCard).dy,
        lessThan(tester.getTopLeft(sodiumCard).dy),
      );
      expect(
        tester.getBottomLeft(sodiumCard).dy,
        lessThan(tester.getTopLeft(sugarCard).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('today diet shows API macro grams without label percentages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        const DietRecordPage(),
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 오늘 4끼 합계 = 탄140·단79·지72g.
    expect(find.text('탄수화물'), findsOneWidget);
    expect(find.textContaining('탄수화물 45%'), findsNothing);
    expect(find.textContaining('120 / 275g'), findsOneWidget);
    expect(find.text('단백질'), findsOneWidget);
    expect(find.textContaining('단백질 17%'), findsNothing);
    expect(find.textContaining('45 / 100g'), findsOneWidget); // 단백질 45g
    expect(find.text('지방'), findsOneWidget);
    expect(find.textContaining('지방 38%'), findsNothing);
    expect(find.textContaining('45 / 55g'), findsOneWidget); // 지방 45g
    void expectMacroProgressColor(String label, Color expectedColor) {
      final Finder progress = find.byKey(
        Key('nutrition-macro-progress-$label'),
      );
      final List<ColoredBox> progressColors = tester
          .widgetList<ColoredBox>(
            find.descendant(of: progress, matching: find.byType(ColoredBox)),
          )
          .toList();
      expect(progressColors.last.color, expectedColor);
    }

    final Color macroProgressColor = FigmaColors.primaryA(0.65);
    expectMacroProgressColor('탄수화물', macroProgressColor);
    expectMacroProgressColor('단백질', macroProgressColor);
    expectMacroProgressColor('지방', macroProgressColor);
    expect(
      tester.getTopLeft(find.text('탄수화물')).dx,
      lessThan(tester.getTopLeft(find.text('단백질')).dx),
    );
    expect(
      tester.getTopLeft(find.text('단백질')).dx,
      lessThan(tester.getTopLeft(find.text('지방')).dx),
    );
    expect(find.text('짬뽕'), findsOneWidget);
  });

  testWidgets('selecting a past date shows that date records', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const DietRecordPage(),
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(_PastDateDietRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _selectDaysAgo(tester);

    expect(find.text('과거 식사'), findsOneWidget);
    expect(find.text('선택한 날짜의 피드백'), findsOneWidget);
    expect(find.textContaining('420'), findsWidgets);
  });

  testWidgets('seeded past meals use their registered photos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const DietRecordPage(),
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _selectDaysAgo(tester);

    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName);
    expect(
      assets,
      containsAll(<String>[
        'assets/images/diet-oatmeal-banana.jpeg',
        'assets/images/diet-chicken-salad.jpg',
        'assets/images/diet-doenjang-rice.jpeg',
      ]),
    );
  });

  testWidgets('a past date without records shows the empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const DietRecordPage(),
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _selectDaysAgo(tester, 3);

    expect(find.textContaining('선택한 날짜에 기록된 식단'), findsOneWidget);
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(DietRecordPage)),
        ).dietLoadError,
      ),
      findsNothing,
    );
  });

  testWidgets('a date lookup error is not shown as an empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const DietRecordPage(),
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(
            _PastDateDietRepository(fail: true),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _selectDaysAgo(tester);

    expect(find.text('식단 정보를 불러오지 못했어요.'), findsOneWidget);
    expect(find.textContaining('선택한 날짜에 기록된 식단'), findsNothing);
  });

  testWidgets('나트륨과 당류는 같은 색 규칙을 쓴다 — 정상 초록 (#682)', (
    WidgetTester tester,
  ) async {
    // 목표 안쪽 값. 두 지표가 같은 카드에 나란히 놓이므로 "정상"을 서로 다른
    // 색으로 말하면 안 된다.
    const DietDay day = DietDay(
      entries: <DietEntry>[
        DietEntry(
          id: 'ok',
          mealType: MealType.lunch,
          timeLabel: '12:00',
          foods: <FoodItem>[
            FoodItem(name: '샐러드', calories: 300, sodiumMg: 400, sugarG: 5),
          ],
          totalCalories: 300,
          sodiumMg: 400,
          sugarG: 5,
          carbsG: 20,
          proteinG: 20,
          fatG: 10,
        ),
      ],
      totalCalories: 300,
      totalSodiumMg: 400,
      totalSugarG: 5,
      macros: DietMacros(
        carbsPct: 40,
        proteinPct: 40,
        fatPct: 20,
        carbsG: 20,
        proteinG: 20,
        fatG: 10,
      ),
      aiCoachMessage: '',
    );

    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SingleChildScrollView(child: NutritionSummary(day: day)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color barColor(String label) {
      final ColoredBox box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byKey(Key('nutrition-status-vertical-progress-$label')),
              matching: find.byType(ColoredBox),
            )
            .last,
      );
      return box.color;
    }

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(NutritionSummary)),
    );
    expect(
      barColor(l.dietSodium),
      barColor(l.dietSugar),
      reason: '정상 범위의 나트륨과 당류가 다른 색이면 안 된다',
    );
    expect(barColor(l.dietSodium), FigmaColors.greenText);
  });

  testWidgets('목표를 넘기면 달성률이 100% 를 넘어 적힌다 (#846)', (
    WidgetTester tester,
  ) async {
    // 기본 목표는 2,000 kcal. 2,500 kcal 은 125% 다 — 여기가 100% 로 적히면
    // 같은 카드의 "목표보다 500 kcal 많아요" 와 어긋난다.
    const DietDay day = DietDay(
      entries: <DietEntry>[
        DietEntry(
          id: 'over',
          mealType: MealType.dinner,
          timeLabel: '19:00',
          foods: <FoodItem>[
            FoodItem(name: '삼겹살 정식', calories: 2500, sodiumMg: 900, sugarG: 8),
          ],
          totalCalories: 2500,
          sodiumMg: 900,
          sugarG: 8,
          carbsG: 120,
          proteinG: 90,
          fatG: 130,
        ),
      ],
      totalCalories: 2500,
      totalSodiumMg: 900,
      totalSugarG: 8,
      macros: DietMacros(
        carbsPct: 35,
        proteinPct: 25,
        fatPct: 40,
        carbsG: 120,
        proteinG: 90,
        fatG: 130,
      ),
      aiCoachMessage: '',
    );

    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SingleChildScrollView(child: NutritionSummary(day: day)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('125%'), findsOneWidget);
    expect(
      find.text('100%'),
      findsNothing,
      reason: '초과인데 100% 로 멈추면 안 된다',
    );

    // 링은 1.0 을 넘으면 눈금이 깨진다. 라벨과 달리 잘린 값을 받아야 한다.
    final CircularProgressIndicator ring = tester
        .widget<CircularProgressIndicator>(
          find.byKey(const Key('nutrition-calorie-progress')),
        );
    expect(ring.value, 1.0);
  });

  testWidgets('목표 안쪽이면 달성률이 실제 비율 그대로 적힌다 (#846)', (
    WidgetTester tester,
  ) async {
    const DietDay day = DietDay(
      entries: <DietEntry>[
        DietEntry(
          id: 'under',
          mealType: MealType.lunch,
          timeLabel: '12:00',
          foods: <FoodItem>[
            FoodItem(name: '비빔밥', calories: 1000, sodiumMg: 800, sugarG: 6),
          ],
          totalCalories: 1000,
          sodiumMg: 800,
          sugarG: 6,
          carbsG: 60,
          proteinG: 30,
          fatG: 20,
        ),
      ],
      totalCalories: 1000,
      totalSodiumMg: 800,
      totalSugarG: 6,
      macros: DietMacros(
        carbsPct: 50,
        proteinPct: 25,
        fatPct: 25,
        carbsG: 60,
        proteinG: 30,
        fatG: 20,
      ),
      aiCoachMessage: '',
    );

    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SingleChildScrollView(child: NutritionSummary(day: day)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsOneWidget);
    final CircularProgressIndicator ring = tester
        .widget<CircularProgressIndicator>(
          find.byKey(const Key('nutrition-calorie-progress')),
        );
    expect(ring.value, 0.5);
  });
}
