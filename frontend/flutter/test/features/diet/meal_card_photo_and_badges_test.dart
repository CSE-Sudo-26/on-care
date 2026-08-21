/// 끼니 카드의 정상 배지 색과, 수정 화면 상단의 큰 사진 (#1053).
///
/// 배지는 같은 탭 안에서 뜻이 하나여야 한다. 기간 그래프와 나트륨·당류 카드가
/// 이미 초록으로 `정상` 을 말하는데 끼니 카드만 파랑이면, 파랑이 정상인지
/// 다른 종류의 지표인지 화면만 보고는 알 수 없다.
///
/// 수정 화면은 무엇을 고치는 끼니인지부터 보여 준다 — 사진을 먼저 확인하고
/// 숫자를 고치는 순서다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_flows.dart';
import 'package:oncare/features/diet/presentation/widgets/meal_photo_view.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../helpers/fake_diet_repository.dart';

/// 대역의 아침 — 사진 자산이 붙어 있는 끼니다.
const DietMeal _breakfast = DietMeal(
  id: 'entry-breakfast',
  mealType: MealType.breakfast,
  time: '08:20',
  total: 217,
  emoji: '🥣',
  thumbBg: Color(0xFFFFF3E0),
  photoAsset: 'assets/images/breakfast-scrambled-egg-strawberry.jpg',
  items: <DietFood>[DietFood('스크램블 에그', 185), DietFood('딸기', 32)],
  tags: <DietTag>[],
  sodium: 221,
  sugar: 6.3,
);

void main() {
  Future<void> pumpDiet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DietRecordPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 배지 안에서 **값** 에 칠해진 색. 라벨은 같은 색을 옅게 쓰므로 마지막으로
  /// 색이 지정된 조각이 값이다. `Text.rich` 가 스팬을 한 겹 감싸 두어 곧장
  /// `children.last` 를 보면 색이 없는 껍데기가 잡힌다.
  Color? badgeColorOf(WidgetTester tester, String text) {
    // 끼니마다 같은 배지가 있다 — 첫 끼니 것만 본다.
    final RichText rich = tester
        .widgetList<RichText>(
          find.byWidgetPredicate(
            (Widget w) =>
                w is RichText && w.text.toPlainText().startsWith('$text '),
          ),
        )
        .first;
    Color? color;
    rich.text.visitChildren((InlineSpan span) {
      if (span.style?.color != null) color = span.style!.color;
      return true;
    });
    return color;
  }

  testWidgets('끼니 카드의 정상 배지는 기간 그래프와 같은 초록이다', (WidgetTester tester) async {
    await pumpDiet(tester);

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(DietRecordPage)),
    );
    // 대역의 아침은 217kcal · 나트륨 320mg — 세 지표 모두 정상 범위다.
    expect(badgeColorOf(tester, l.dietCalories), FigmaColors.statusNormal);
    expect(badgeColorOf(tester, l.dietSugar), FigmaColors.statusNormal);
    expect(badgeColorOf(tester, l.dietSodium), FigmaColors.statusNormal);
  });

  testWidgets('목록 썸네일은 정사각 52 다', (WidgetTester tester) async {
    await pumpDiet(tester);

    final List<MealPhotoView> thumbs = tester
        .widgetList<MealPhotoView>(find.byType(MealPhotoView))
        .toList();
    expect(thumbs, isNotEmpty);
    expect(thumbs.every((MealPhotoView p) => p.height == 52), isTrue);
  });

  testWidgets('끼니를 열면 상단에 사진이 크게 뜬다', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 수정 화면은 탭 껍데기 위에 라우터로 열린다 — 여기서는 그 페이지만 띄운다.
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DietMealDetailPage(
            entryId: _breakfast.id!,
            initialMeal: _breakfast,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final MealPhotoView hero = tester.widget<MealPhotoView>(
      find.byType(MealPhotoView).first,
    );
    expect(hero.height, greaterThan(52));
    expect(hero.width, double.infinity);
    // 목록과 같은 사진을 고른다 — 두 화면이 각자 고르면 어긋난다.
    expect(hero.photoAsset, _breakfast.photoAsset);
  });
}
