import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/diet_period.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../helpers/fake_diet_repository.dart';

/// 짝수 날에만 기록이 있는 저장소 — 기간 평균이 **기록이 있는 날만으로**
/// 나뉘는지 확인하기 위한 대역.
class _SparseDietRepository extends FakeDietRepository {
  @override
  Future<DietDay> fetchByDate(DateTime date) async {
    if (date.day.isOdd) {
      return const DietDay(
        entries: <DietEntry>[],
        totalCalories: 0,
        totalSodiumMg: 0,
        totalSugarG: 0,
        macros: DietMacros.zero(),
        aiCoachMessage: '',
      );
    }
    return const DietDay(
      entries: <DietEntry>[
        DietEntry(
          id: 'e',
          mealType: MealType.lunch,
          timeLabel: '12:00',
          foods: <FoodItem>[
            FoodItem(name: '점심', calories: 600, sodiumMg: 1000, sugarG: 10),
          ],
          totalCalories: 600,
          sodiumMg: 1000,
          sugarG: 10,
          carbsG: 60,
          proteinG: 30,
          fatG: 20,
        ),
      ],
      totalCalories: 600,
      totalSodiumMg: 1000,
      totalSugarG: 10,
      macros: DietMacros(
        carbsPct: 40,
        proteinPct: 20,
        fatPct: 40,
        carbsG: 60,
        proteinG: 30,
        fatG: 20,
      ),
      aiCoachMessage: '',
    );
  }
}

Widget _app({List<Override> overrides = const <Override>[]}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      locale: Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DietRecordPage(),
    ),
  );
}

void main() {
  group('dietPeriodProvider', () {
    test('기간의 모든 날을 담고, 평균은 기록이 있는 날만으로 나눈다', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(_SparseDietRepository()),
        ],
      );
      addTearDown(container.dispose);

      // 2026-06-01(월) ~ 06-07(일): 짝수 날 3일(2·4·6)만 기록이 있다.
      final DietPeriod period = await container.read(
        dietPeriodProvider((
          from: DateTime(2026, 6),
          to: DateTime(2026, 6, 7),
        )).future,
      );

      expect(period.days.length, 7);
      expect(period.loggedDays, 3);
      expect(period.totalCalories, 1800);
      // 7 이 아니라 3 으로 나눈다 — 기록하지 않은 날의 0 이 평균을 끌어내리면
      // 실제로 먹은 양과 다른 숫자가 된다.
      expect(period.avgCalories, 600);
      expect(period.avgSodiumMg, 1000);
      expect(period.avgSugarG, closeTo(10, 0.001));
    });

    test('기록이 하나도 없는 기간은 비어 있다고 본다(0 으로 나누지 않는다)', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(_EmptyDietRepository()),
        ],
      );
      addTearDown(container.dispose);

      final DietPeriod period = await container.read(
        dietPeriodProvider((
          from: DateTime(2026, 6),
          to: DateTime(2026, 6, 7),
        )).future,
      );

      expect(period.isEmpty, isTrue);
      expect(period.avgCalories, 0);
    });
  });

  group('영양 요약 기간 뷰 배치 (#694)', () {
    Future<AppLocalizations> pumpWeek(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          overrides: <Override>[
            dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
            accountRepositoryProvider.overrideWithValue(
              MockAccountRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('diet-period-tab-week')));
      await tester.pumpAndSettle();
      return AppLocalizations.of(tester.element(find.byType(DietRecordPage)));
    }

    testWidgets('지표 버튼 셋이 모두 같은 색이다', (WidgetTester tester) async {
      // 지표마다 색이 다르면 고르기 전부터 셋이 서로 다른 뜻을 가진 것처럼
      // 보인다. 버튼은 '무엇을 고르는가' 만 말해야 한다.
      final AppLocalizations l = await pumpWeek(tester);

      // 고른 것과 안 고른 것의 색이 다른 건 정상이다. 비교할 것은 **각 버튼을
      // 골랐을 때의 색** 이 셋 다 같은가다.
      final Set<Color?> activeColors = <Color?>{};
      for (final String label in <String>[
        l.dietCalories,
        l.dietSodium,
        l.dietSugar,
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        activeColors.add(tester.widget<Text>(find.text(label)).style?.color);
      }

      expect(
        activeColors,
        hasLength(1),
        reason: '지표 버튼 색이 서로 다릅니다: $activeColors',
      );
    });

    testWidgets('날짜 범위가 지표 버튼과 같은 줄에 있다', (WidgetTester tester) async {
      // 범위가 따로 한 줄을 쓰면 제목·범위·버튼 세 줄이 되어 그래프가 밀린다.
      final AppLocalizations l = await pumpWeek(tester);
      final Finder range = find.textContaining(RegExp(r'~|–|-'));

      final Finder rangeInRow = find.descendant(
        of: find.ancestor(
          of: find.text(l.dietCalories),
          matching: find.byType(Row),
        ),
        matching: range,
      );
      expect(
        rangeInRow,
        findsWidgets,
        reason: '날짜 범위가 지표 버튼과 다른 줄에 있습니다.',
      );
    });
  });

  group('식단 탭 기간 토글', () {
    testWidgets('끼니 목록 제목은 날짜에 매이지 않고 어느 날 기록인지 함께 적는다 (#687)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          overrides: <Override>[
            dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
            accountRepositoryProvider.overrideWithValue(
              MockAccountRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final Element context = tester.element(find.byType(DietRecordPage));
      final AppLocalizations l = AppLocalizations.of(context);

      // 이 목록은 늘 **선택한 날**을 보여 준다. 제목이 '오늘' 을 주장하면 사흘 전을
      // 골랐을 때 거짓말이 된다 — 그게 #687 이 신고된 경로다.
      expect(find.text(l.dietMealLog), findsOneWidget);
      expect(l.dietMealLog.contains('오늘'), isFalse);
      expect(l.dietMealLog.toLowerCase().contains('today'), isFalse);

      // 대신 어느 날 기록인지가 제목 옆에 적혀 있다. 기간 토글을 이번 주로 두면
      // 7 일짜리 그래프 밑에 하루치 목록이 붙으므로, 날짜가 없으면 읽히지 않는다.
      final String todayLabel = MaterialLocalizations.of(
        context,
      ).formatMediumDate(DateTime.now());
      expect(find.text(todayLabel), findsWidgets);
    });

    testWidgets('토글은 영양 요약 섹션만 바꾸고, 날짜 스트립·끼니 목록은 남는다 (#681)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          overrides: <Override>[
            dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
            accountRepositoryProvider.overrideWithValue(
              MockAccountRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final AppLocalizations l = AppLocalizations.of(
        tester.element(find.byType(DietRecordPage)),
      );

      // 처음에는 하루 요약.
      expect(find.byKey(const Key('nutrition-summary-card')), findsOneWidget);
      expect(find.byKey(const Key('diet-period-card')), findsNothing);
      // 제목은 기간과 무관한 '영양 요약'.
      expect(find.text(l.dietNutritionSummary), findsOneWidget);
      expect(l.dietNutritionSummary.contains('오늘'), isFalse);

      await tester.tap(find.byKey(const Key('diet-period-tab-week')));
      await tester.pumpAndSettle();

      // 요약 자리만 그래프로 바뀐다.
      expect(find.byKey(const Key('diet-period-card')), findsOneWidget);
      expect(find.byKey(const Key('nutrition-summary-card')), findsNothing);
      // 날짜 스트립과 끼니 목록은 그대로 남는다 — 운동 탭과 같은 규칙.
      expect(find.text(l.dietMealLog), findsOneWidget);
      expect(find.text(l.dietAddMeal), findsOneWidget);
      // 토글도 제목 줄에 그대로 있다.
      expect(find.byKey(const Key('diet-period-tab-month')), findsOneWidget);

      await tester.tap(find.byKey(const Key('diet-period-tab-month')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diet-period-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('diet-period-tab-day')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nutrition-summary-card')), findsOneWidget);
      expect(find.byKey(const Key('diet-period-card')), findsNothing);
    });
  });

  group('dietRangeForTab', () {
    test('이번 주는 월~일 7일이다 (일요일에도 그 주로 묶인다)', () {
      // 2026-06-07 은 일요일 → weekday 7. Duration 으로 빼면 다음 주로 샌다.
      final DietDateRange r = dietRangeForTab(
        DietPeriodTab.week,
        DateTime(2026, 6, 7),
      );
      expect(r.from, DateTime(2026, 6));
      expect(r.to, DateTime(2026, 6, 7));
      expect(dietRangeDates(r).length, 7);
    });

    test('12월은 다음 해로 넘어가지 않고 12월 31일에서 끝난다', () {
      final DietDateRange r = dietRangeForTab(
        DietPeriodTab.month,
        DateTime(2026, 12, 15),
      );
      expect(r.from, DateTime(2026, 12));
      expect(r.to, DateTime(2026, 12, 31));
      expect(dietRangeDates(r).length, 31);
    });

    test('2월은 윤년 여부에 따라 28·29일이다', () {
      expect(
        dietRangeDates(
          dietRangeForTab(DietPeriodTab.month, DateTime(2026, 2, 10)),
        ).length,
        28,
      );
      expect(
        dietRangeDates(
          dietRangeForTab(DietPeriodTab.month, DateTime(2028, 2, 10)),
        ).length,
        29,
      );
    });

    test('서머타임이 시작하는 3월도 말일이 빠지지 않는다', () {
      // 로컬 자정끼리 빼면 29일 23시간 → inDays 29 로 잘려 3월 31일이 빠졌다.
      final DietDateRange r = dietRangeForTab(
        DietPeriodTab.month,
        DateTime(2026, 3, 15),
      );
      final List<DateTime> dates = dietRangeDates(r);
      expect(dates.length, 31);
      expect(dates.last.day, 31);
    });
  });

  test('음식 배열이 비어 있으면 서버가 준 하루 합계로 떨어진다', () async {
    // 실서버 응답은 영양을 하루/끼니 단위로만 내려준다.
    final container = ProviderContainer(
      overrides: <Override>[
        dietRepositoryProvider.overrideWithValue(_DayTotalsOnlyRepository()),
      ],
    );
    addTearDown(container.dispose);

    final DietPeriod period = await container.read(
      dietPeriodProvider((
        from: DateTime(2026, 6),
        to: DateTime(2026, 6, 2),
      )).future,
    );

    expect(period.loggedDays, 2);
    expect(period.avgCalories, 500);
    expect(period.avgSodiumMg, 800);
    expect(period.avgSugarG, closeTo(9, 0.001));
  });

  group('기간 뷰는 선택한 날짜 요청에 좌우되지 않는다 (#684 리뷰)', () {
    testWidgets('기록이 빈 날을 골라도 그래프와 토글이 남는다', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          overrides: <Override>[
            // 어제만 비어 있고 나머지는 기록이 있다 — 주간 집계는 충분하다.
            dietRepositoryProvider.overrideWithValue(
              _EmptyYesterdayRepository(),
            ),
            accountRepositoryProvider.overrideWithValue(
              MockAccountRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('diet-period-tab-week')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diet-period-card')), findsOneWidget);

      final DateTime yesterday = DateTime.now().subtract(
        const Duration(days: 1),
      );
      await tester.tap(find.text('${yesterday.day}').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('diet-period-card')),
        findsOneWidget,
        reason: '하루 기록이 비었다고 기간 그래프가 사라지면 안 된다',
      );
      expect(
        find.byKey(const Key('diet-period-tab-day')),
        findsOneWidget,
        reason: '토글이 사라지면 오늘로 돌아갈 방법이 없다',
      );
    });

    testWidgets('하루 조회가 실패해도 토글이 남는다', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          overrides: <Override>[
            dietRepositoryProvider.overrideWithValue(_FailPastRepository()),
            accountRepositoryProvider.overrideWithValue(
              MockAccountRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('diet-period-tab-week')));
      await tester.pumpAndSettle();

      final DateTime yesterday = DateTime.now().subtract(
        const Duration(days: 1),
      );
      await tester.tap(find.text('${yesterday.day}').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diet-period-tab-day')), findsOneWidget);
    });
  });
}

/// 어느 날짜에도 기록이 없는 저장소.
class _EmptyDietRepository extends FakeDietRepository {
  @override
  Future<DietDay> fetchByDate(DateTime date) async => const DietDay(
    entries: <DietEntry>[],
    totalCalories: 0,
    totalSodiumMg: 0,
    totalSugarG: 0,
    macros: DietMacros.zero(),
    aiCoachMessage: '',
  );
}

/// 끼니에 음식 상세가 없고 하루 합계만 있는 저장소(실서버 페이로드 모양).
class _DayTotalsOnlyRepository extends FakeDietRepository {
  @override
  Future<DietDay> fetchByDate(DateTime date) async => const DietDay(
    entries: <DietEntry>[
      DietEntry(
        id: 'e',
        mealType: MealType.lunch,
        timeLabel: '12:00',
        foods: <FoodItem>[],
        totalCalories: 500,
        sodiumMg: 800,
        sugarG: 9,
      ),
    ],
    totalCalories: 500,
    totalSodiumMg: 800,
    totalSugarG: 9,
    macros: DietMacros.zero(),
    aiCoachMessage: '',
  );
}

/// 어제만 비어 있는 저장소.
class _EmptyYesterdayRepository extends FakeDietRepository {
  @override
  Future<DietDay> fetchByDate(DateTime date) async {
    final DateTime y = DateTime.now().subtract(const Duration(days: 1));
    if (date.year == y.year && date.month == y.month && date.day == y.day) {
      return const DietDay(
        entries: <DietEntry>[],
        totalCalories: 0,
        totalSodiumMg: 0,
        totalSugarG: 0,
        macros: DietMacros.zero(),
        aiCoachMessage: '',
      );
    }
    return super.fetchByDate(date);
  }
}

/// 오늘이 아닌 날짜 조회가 실패하는 저장소.
class _FailPastRepository extends FakeDietRepository {
  @override
  Future<DietDay> fetchByDate(DateTime date) async {
    if (date.day != DateTime.now().day) throw StateError('boom');
    return super.fetchByDate(date);
  }
}
