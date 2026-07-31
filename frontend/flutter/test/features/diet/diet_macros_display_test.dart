import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('today diet shows API macro grams and percentages', (
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

    expect(find.text('탄수화물 43%'), findsOneWidget);
    expect(find.textContaining('113'), findsOneWidget);
    expect(find.text('단백질 17%'), findsOneWidget);
    // 단백질 46g / 지방 46.5g 이 '46' 을 공유하므로 단위까지 붙여 구분한다.
    expect(find.textContaining('46 g'), findsOneWidget);
    expect(find.text('지방 40%'), findsOneWidget);
    expect(find.textContaining('46.5'), findsOneWidget);
    expect(find.text('짬뽕'), findsOneWidget);
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

    expect(find.text('탄수화물 100g · 단백질 30g · 지방 24g'), findsOneWidget);
    expect(
      find.text('탄수화물 100g · 단백질 30g · 지방 24g · 나트륨 3200mg'),
      findsOneWidget,
    );
  });
}
