import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_entry_detail_page.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

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

class _PastDateDietRepository extends MockDietRepository {
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
  testWidgets(
    'nutrition summary highlights progress and status on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(340, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final DietDay day =
          await tester.runAsync(() => MockDietRepository().fetchToday())
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
      expect(find.textContaining('1,517'), findsOneWidget);
      expect(find.textContaining('2,000 kcal'), findsOneWidget);
      expect(find.textContaining('4,008'), findsOneWidget);
      expect(find.textContaining('24.8'), findsOneWidget);
      expect(find.text('목표 초과'), findsOneWidget);
      expect(find.text('정상'), findsOneWidget);
      expect(find.text('목표보다 2,008mg 많아요'), findsOneWidget);
      expect(find.text('목표까지 25.2g 남았어요'), findsOneWidget);
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
          dietRepositoryProvider.overrideWithValue(MockDietRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 오늘 4끼 합계 = 탄140·단79·지72g.
    expect(find.text('탄수화물'), findsOneWidget);
    expect(find.textContaining('탄수화물 45%'), findsNothing);
    expect(find.textContaining('140 / 275g'), findsOneWidget);
    expect(find.text('단백질'), findsOneWidget);
    expect(find.textContaining('단백질 17%'), findsNothing);
    expect(find.textContaining('79 / 100g'), findsOneWidget); // 단백질 79g
    expect(find.text('지방'), findsOneWidget);
    expect(find.textContaining('지방 38%'), findsNothing);
    expect(find.textContaining('72 / 55g'), findsOneWidget); // 지방 72g
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
          dietRepositoryProvider.overrideWithValue(MockDietRepository()),
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
          dietRepositoryProvider.overrideWithValue(MockDietRepository()),
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

  testWidgets('diet detail shows meal and food macro values', (tester) async {
    final DietDay day =
        await tester.runAsync(() => MockDietRepository().fetchToday())
            as DietDay;
    final lunch = day.entries.firstWhere(
      (entry) => entry.mealType == MealType.lunch,
    );

    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(DietEntryDetailPage(entry: lunch)));
    await tester.pump();

    expect(find.text('탄수화물 107g · 단백질 29g · 지방 22.5g'), findsOneWidget);
    expect(
      find.text('탄수화물 107g · 단백질 29g · 지방 22.5g · 나트륨 3200mg'),
      findsOneWidget,
    );
  });
}
