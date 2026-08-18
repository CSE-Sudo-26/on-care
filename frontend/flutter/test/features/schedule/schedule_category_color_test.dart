import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/presentation/schedule_category_color.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

void main() {
  test('each category maps to a distinct color', () {
    final colors = ScheduleCategory.values.map(scheduleCategoryColor).toList();
    expect(
      colors.toSet().length,
      ScheduleCategory.values.length,
      reason: 'categories must be visually distinguishable on the calendar',
    );
  });

  test('same category always maps to the same color', () {
    for (final ScheduleCategory c in ScheduleCategory.values) {
      expect(scheduleCategoryColor(c), scheduleCategoryColor(c));
    }
  });

  // 라벨은 로케일을 따른다(#847). 두 로케일 모두에서 빈 칸이 없어야 한다 —
  // 한 쪽만 채워 두면 다른 쪽에서 칩이 빈 채로 그려진다.
  for (final String lang in <String>['ko', 'en']) {
    testWidgets('$lang 로케일에서 모든 카테고리에 이름이 있다', (
      WidgetTester tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              l = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final labels = <String>[
        for (final ScheduleCategory c in ScheduleCategory.values)
          scheduleCategoryLabel(l, c),
      ];
      expect(labels.every((String s) => s.isNotEmpty), isTrue);
      expect(
        labels.toSet().length,
        ScheduleCategory.values.length,
        reason: '두 카테고리가 같은 이름으로 보이면 안 된다',
      );
    });
  }
}
