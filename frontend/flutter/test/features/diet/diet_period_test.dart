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

  group('식단 탭 기간 토글', () {
    testWidgets('이번 주를 고르면 기간 추이 카드가 나오고, 오늘로 돌아오면 끼니 목록이 돌아온다', (
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

      // 처음에는 하루 뷰.
      expect(find.byKey(const Key('nutrition-summary-card')), findsOneWidget);
      expect(find.byKey(const Key('diet-period-card')), findsNothing);

      await tester.tap(find.byKey(const Key('diet-period-tab-week')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diet-period-card')), findsOneWidget);
      expect(find.byKey(const Key('nutrition-summary-card')), findsNothing);

      await tester.tap(find.byKey(const Key('diet-period-tab-month')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diet-period-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('diet-period-tab-day')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nutrition-summary-card')), findsOneWidget);
      expect(find.byKey(const Key('diet-period-card')), findsNothing);
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
