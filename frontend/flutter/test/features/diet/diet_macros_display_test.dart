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
          dietRepositoryProvider.overrideWithValue(const MockDietRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('탄수화물 44%'), findsOneWidget);
    expect(find.text('203.6'), findsOneWidget);
    expect(find.text('단백질 24%'), findsOneWidget);
    expect(find.text('109.3'), findsOneWidget);
    expect(find.text('지방 32%'), findsOneWidget);
    expect(find.text('66.5'), findsOneWidget);
    expect(find.text('김치찌개'), findsOneWidget);
    expect(find.text('탄수화물 86g'), findsOneWidget);
  });

  testWidgets('diet detail shows meal and food macro values', (tester) async {
    final DietDay day =
        await tester.runAsync(() => const MockDietRepository().fetchToday())
            as DietDay;
    final lunch = day.entries.firstWhere(
      (entry) => entry.mealType == MealType.lunch,
    );

    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(DietEntryDetailPage(entry: lunch)));
    await tester.pump();

    expect(find.text('탄수화물 86g · 단백질 40g · 지방 29.3g'), findsOneWidget);
    expect(
      find.text('탄수화물 16g · 단백질 20g · 지방 15.5g · 나트륨 900mg'),
      findsOneWidget,
    );
  });
}
