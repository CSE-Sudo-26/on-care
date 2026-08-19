import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/diet_period.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../helpers/fake_diet_repository.dart';

/// 이번 달 칼로리 막대는 **탄단지로 쌓아** 그린다.
///
/// 같은 2,000kcal 이라도 밥에서 온 것과 기름에서 온 것은 다른 하루다. 숫자
/// 하나만으로는 그 차이가 화면에 없었다.
class _MacroRepository extends FakeDietRepository {
  @override
  Future<DietDay> fetchByDate(DateTime date) async => _day;

  @override
  Future<DietDay> fetchToday() async => _day;

  /// 탄 200g(800kcal) · 단 100g(400kcal) · 지 40g(360kcal).
  static const DietDay _day = DietDay(
    entries: <DietEntry>[
      DietEntry(
        id: 'e',
        mealType: MealType.lunch,
        timeLabel: '12:00',
        foods: <FoodItem>[
          FoodItem(
            name: '한 끼',
            calories: 1560,
            sodiumMg: 1200,
            sugarG: 12,
            carbsG: 200,
            proteinG: 100,
            fatG: 40,
          ),
        ],
        totalCalories: 1560,
        sodiumMg: 1200,
        sugarG: 12,
        carbsG: 200,
        proteinG: 100,
        fatG: 40,
      ),
    ],
    totalCalories: 1560,
    totalSodiumMg: 1200,
    totalSugarG: 12,
    macros: DietMacros(
      carbsPct: 51,
      proteinPct: 26,
      fatPct: 23,
      carbsG: 200,
      proteinG: 100,
      fatG: 40,
    ),
    aiCoachMessage: '',
  );
}

Widget _app({required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    locale: Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DietRecordPage(),
  ),
);

void main() {
  group('DietPeriodDay 탄단지', () {
    test('탄·단은 4kcal/g, 지방은 9kcal/g 로 환산한다', () {
      final DietPeriodDay day = DietPeriodDay(
        date: _anyDate,
        calories: 1560,
        sodiumMg: 1200,
        sugarG: 12,
        carbsG: 200,
        proteinG: 100,
        fatG: 40,
      );

      expect(day.carbsKcal, 800);
      expect(day.proteinKcal, 400);
      expect(day.fatKcal, 360);
      expect(day.hasMacros, isTrue);
    });

    test('영양이 없는 날은 쌓지 않는다', () {
      final DietPeriodDay day = DietPeriodDay(
        date: _anyDate,
        calories: 1200,
        sodiumMg: 900,
        sugarG: 8,
      );

      expect(day.hasMacros, isFalse);
    });
  });

  group('이번 달 칼로리 막대 (#7)', () {
    Future<void> openMonth(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          overrides: <Override>[
            dietRepositoryProvider.overrideWithValue(_MacroRepository()),
            accountRepositoryProvider.overrideWithValue(
              MockAccountRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('diet-period-tab-month')));
      await tester.pumpAndSettle();
    }

    List<Color> segmentColorsOf(WidgetTester tester, int index) => tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byKey(Key('diet-period-bar-$index')),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((ColoredBox b) => b.color)
        .toList();

    /// 구간의 **그려진 사각형**. 색만 확인하면 폭 0 을 그대로 통과시킨다 —
    /// 실제로 #947 이 그렇게 새어 나갔다.
    List<Rect> segmentRectsOf(WidgetTester tester, int index) => <Rect>[
      // `find.byWidget` 은 쓸 수 없다 — 세 구간이 const 라 서른한 칸의 같은
      // 색 구간이 전부 같은 위젯으로 잡힌다. Element 의 RenderBox 에서 직접
      // 잰다.
      for (final Element e
          in find
              .descendant(
                of: find.byKey(Key('diet-period-bar-$index')),
                matching: find.byType(ColoredBox),
              )
              .evaluate())
        (e.renderObject! as RenderBox).localToGlobal(Offset.zero) &
            (e.renderObject! as RenderBox).size,
    ];

    testWidgets('쌓은 구간이 막대 폭을 채운다 (#947)', (WidgetTester tester) async {
      await openMonth(tester);

      final Rect bar = tester.getRect(
        find.byKey(const Key('diet-period-bar-0')),
      );
      final List<Rect> segments = segmentRectsOf(tester, 0);
      expect(segments, hasLength(3));

      for (final Rect seg in segments) {
        // Column 의 기본 정렬(center)이면 자식 없는 ColoredBox 가 폭 0 으로
        // 그려져 막대가 통째로 사라진다.
        expect(seg.width, greaterThan(0));
        expect(seg.width, closeTo(bar.width, 0.5));
      }

      // 세 구간을 합치면 막대 높이가 된다 — 한 조각이 빠지면 여기서 드러난다.
      final double stacked = segments.fold<double>(
        0,
        (double a, Rect r) => a + r.height,
      );
      expect(stacked, closeTo(bar.height, 0.5));
      expect(bar.height, greaterThan(0));
    });

    testWidgets('구간 높이가 칼로리 기여분을 따른다 (#947)', (WidgetTester tester) async {
      await openMonth(tester);

      // 탄 200g(800kcal) · 단 100g(400kcal) · 지 40g(360kcal) = 1,560kcal.
      // 위에서부터 지방 · 단백질 · 탄수화물 순으로 쌓인다.
      final List<Rect> segments = segmentRectsOf(tester, 0);
      final double total = segments.fold<double>(
        0,
        (double a, Rect r) => a + r.height,
      );
      expect(segments[0].height / total, closeTo(360 / 1560, 0.02));
      expect(segments[1].height / total, closeTo(400 / 1560, 0.02));
      expect(segments[2].height / total, closeTo(800 / 1560, 0.02));
    });

    testWidgets('막대가 탄단지 3색으로 쌓인다', (WidgetTester tester) async {
      await openMonth(tester);

      // 위에서부터 지방 · 단백질 · 탄수화물 — 바닥부터 읽으면 라벨 순서와 같다.
      expect(segmentColorsOf(tester, 0), <Color>[
        FigmaColors.macroFat,
        FigmaColors.macroProtein,
        FigmaColors.macroCarbs,
      ]);
    });

    testWidgets('세 색은 브랜드 색의 농담이다 (#953)', (WidgetTester tester) async {
      // `오늘` 뷰가 칼로리 링도 탄단지 진행 바도 브랜드 색 하나로 그린다.
      // 기간 뷰만 다른 색상환을 쓰면 토글로 두 뷰를 오갈 때 색이 튄다.
      expect(FigmaColors.macroCarbs, FigmaColors.primary);

      // 위로 갈수록 옅어진다 — 한 칼로리를 나눈 것이라 색상보다 농담으로
      // 가르는 편이 뜻에 맞는다.
      double lum(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
      expect(
        lum(FigmaColors.macroProtein),
        greaterThan(lum(FigmaColors.macroCarbs)),
      );
      expect(
        lum(FigmaColors.macroFat),
        greaterThan(lum(FigmaColors.macroProtein)),
      );

      // 목표선 위에 겹쳐 그리므로 반투명이면 선이 비친다.
      for (final Color macro in <Color>[
        FigmaColors.macroCarbs,
        FigmaColors.macroProtein,
        FigmaColors.macroFat,
      ]) {
        expect(macro.a, 1.0, reason: '$macro');
      }
    });

    testWidgets('툴팁이 탄단지 수치를 함께 적는다', (WidgetTester tester) async {
      await openMonth(tester);

      final Tooltip tip = tester.widget<Tooltip>(
        find.byKey(Key('diet-period-bar-tip-${nowKst().day - 1}')),
      );
      final String text = tip.richMessage!.toPlainText();

      expect(text, contains('탄수화물'));
      expect(text, contains('200'));
      expect(text, contains('단백질'));
      expect(text, contains('100'));
      expect(text, contains('지방'));
      expect(text, contains('40'));
    });

    testWidgets('나트륨으로 바꾸면 쌓지 않는다', (WidgetTester tester) async {
      await openMonth(tester);

      final AppLocalizations l = AppLocalizations.of(
        tester.element(find.byType(DietRecordPage)),
      );
      await tester.tap(find.text(l.dietSodium));
      await tester.pumpAndSettle();

      // 나트륨에는 쌓을 성분이 없다 — 한 색 막대로 돌아간다.
      expect(segmentColorsOf(tester, 0), isEmpty);
    });
  });
}

final DateTime _anyDate = DateTime(2026, 8, 19);
