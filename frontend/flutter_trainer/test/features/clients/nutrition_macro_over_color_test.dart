/// 탄단지 진행 바가 목표 초과를 색으로 말하는지 (#891).
///
/// 바는 목표 지점에서 멈춘다(`ratio` 가 1.0 으로 잘린다). 색까지 그대로면
/// **꽉 찬 것과 넘긴 것이 완전히 같은 그림**이라, 숫자를 읽지 않으면 구별할 수
/// 없다. 같은 카드의 칼로리 링과 나트륨·당류 바는 이미 이렇게 갈린다.
///
/// 회원 앱과 같은 그림을 보여 주는 것이 이 카드의 존재 이유이므로(#698),
/// 회원 화면에서 빨간 것은 트레이너 화면에서도 빨개야 한다(#690).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/nutrition_summary_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

import '../../helpers/client_factory.dart';

void main() {
  /// [label] 항목의 진행 바에 칠해진 색들.
  List<Color?> barColors(WidgetTester tester, String label) => tester
      .widgetList<ColoredBox>(
        find.descendant(
          of: find.byKey(Key('client-nutrition-macro-$label')),
          matching: find.byType(ColoredBox),
        ),
      )
      .map((ColoredBox box) => box.color)
      .toList();

  Future<void> pumpCard(WidgetTester tester, TrainerClient client) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NutritionSummaryCard(client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('목표를 넘긴 항목만 빨강이 된다', (WidgetTester tester) async {
    // 지방만 초과(56 > 55). 탄수·단백질은 목표 아래.
    await pumpCard(tester, makeClient(carbsG: 120, proteinG: 45, fatG: 56));

    expect(barColors(tester, '지방'), contains(AppColors.overTarget));
    expect(
      barColors(tester, '탄수화물'),
      isNot(contains(AppColors.overTarget)),
      reason: '탄수화물은 목표 아래인데 빨강이 됐습니다.',
    );
    expect(barColors(tester, '단백질'), isNot(contains(AppColors.overTarget)));
  });

  testWidgets('목표 아래면 기존 남색을 유지한다', (WidgetTester tester) async {
    await pumpCard(tester, makeClient(carbsG: 120, proteinG: 45, fatG: 45));

    for (final String label in <String>['탄수화물', '단백질', '지방']) {
      expect(
        barColors(tester, label),
        contains(AppColors.primary.withValues(alpha: 0.65)),
        reason: label,
      );
      expect(barColors(tester, label), isNot(contains(AppColors.overTarget)));
    }
  });

  testWidgets('목표와 정확히 같으면 초과가 아니다', (WidgetTester tester) async {
    // 경계는 다른 지표와 같다 — `>` 지, `>=` 가 아니다.
    await pumpCard(tester, makeClient(carbsG: 275, proteinG: 100, fatG: 55));

    for (final String label in <String>['탄수화물', '단백질', '지방']) {
      expect(
        barColors(tester, label),
        isNot(contains(AppColors.overTarget)),
        reason: label,
      );
    }
  });

  testWidgets('세 항목이 모두 넘으면 셋 다 빨강이다', (WidgetTester tester) async {
    await pumpCard(tester, makeClient(carbsG: 300, proteinG: 140, fatG: 80));

    for (final String label in <String>['탄수화물', '단백질', '지방']) {
      expect(
        barColors(tester, label),
        contains(AppColors.overTarget),
        reason: label,
      );
    }
  });
}
