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

    // 오늘 3끼 합계 = 탄120·단45·지45g → 45/17/38%.
    expect(find.text('탄수화물 45%'), findsOneWidget);
    expect(find.textContaining('120 /275g'), findsOneWidget);
    expect(find.text('단백질 17%'), findsOneWidget);
    expect(find.textContaining('45 /100g'), findsOneWidget); // 단백질 45g
    expect(find.text('지방 38%'), findsOneWidget);
    expect(find.textContaining('45 /55g'), findsOneWidget); // 지방 45g
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

    expect(find.text('탄수화물 107g · 단백질 29g · 지방 22.5g'), findsOneWidget);
    expect(
      find.text('탄수화물 107g · 단백질 29g · 지방 22.5g · 나트륨 3200mg'),
      findsOneWidget,
    );
  });
}
