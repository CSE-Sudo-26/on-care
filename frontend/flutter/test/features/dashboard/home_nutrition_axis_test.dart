/// 홈 "주간 추이" 그래프의 세로축 눈금 라벨.
///
/// 라벨은 값에 비례한 위치에 `Positioned` 로 겹쳐 놓이고 높이는 16px 로 고정이다.
/// 축 높이가 68px 뿐이라 눈금을 촘촘히 두면 라벨끼리 물리적으로 겹쳐 숫자를 읽을
/// 수 없다 — 실제로 칼로리 축이 1,000·1,500·2,000·2,500 네 개일 때 그렇게 겹쳤다.
/// 여기서는 "겹치지 않는다"를 좌표로 못박는다. 눈금을 다시 늘리면 이 테스트가
/// 먼저 깨진다.
///
/// 세 지표 모두 맨 아래 눈금은 0 이어야 한다 — 한 카드에서 탭으로 바뀌는데
/// 축의 바닥이 지표마다 다르면 같은 그래프를 다른 기준으로 읽게 된다 (#548).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

void main() {
  const DashboardSummary summary = DashboardSummary(
    indicators: <HealthIndicator>[
      HealthIndicator(label: '칼로리', current: 1860, max: 2000, unit: 'kcal'),
      HealthIndicator(
        label: '나트륨',
        current: 2329,
        max: 2000,
        unit: 'mg',
        overBudget: true,
      ),
      HealthIndicator(label: '당류', current: 43, max: 50, unit: 'g'),
    ],
    macros: DietMacros(
      carbsG: 203.6,
      proteinG: 109.3,
      fatG: 66.5,
      carbsPct: 44,
      proteinPct: 24,
      fatPct: 32,
    ),
    dietEntries: 4,
    exerciseMinutes: 45,
    exerciseCalories: 520,
    exerciseCount: 4,
    todaySchedule: <ScheduleItem>[],
    weekScore: 85,
    weekScoreDelta: 12,
    sodiumWarning: null,
  );

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          accountRepositoryProvider.overrideWithValue(
            MockAccountRepository(
              profile: const UserProfile(
                id: 'member',
                name: '테스트',
                email: 'member@example.com',
              ),
            ),
          ),
          dashboardSummaryProvider.overrideWith((ref) async => summary),
          memberCoachRepositoryProvider.overrideWithValue(
            MockMemberCoachRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DashboardContent()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 세로축 라벨 칸 — 폭 38 · 높이 68 의 `SizedBox` 하나뿐이다.
  final Finder axis = find.descendant(
    of: find.byKey(const ValueKey<String>('dashboard-nutrition-chart')),
    matching: find.byWidgetPredicate(
      (Widget w) => w is SizedBox && w.width == 38 && w.height == 68,
    ),
  );

  /// 축 라벨을 위에서 아래 순서로 (문구, 사각형) 으로 읽는다.
  ///
  /// 사각형은 글자가 아니라 라벨이 차지한 16px 짜리 칸을 잰다 — 글꼴에 따라
  /// 글자 높이는 달라져도 칸 높이는 레이아웃이 정한 값이라, 겹침 판정이
  /// 테스트 글꼴의 자간에 흔들리지 않는다.
  List<({String text, Rect rect})> axisLabels(WidgetTester tester) {
    final Finder slots = find.descendant(
      of: axis,
      matching: find.byWidgetPredicate(
        (Widget w) => w is SizedBox && w.height == 16,
      ),
    );
    return <({String text, Rect rect})>[
      for (final Element e in slots.evaluate())
        (
          text: (find
                      .descendant(of: find.byWidget(e.widget), matching: find.byType(Text))
                      .evaluate()
                      .single
                      .widget
                  as Text)
              .data!,
          rect: tester.getRect(find.byWidget(e.widget)),
        ),
    ]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
  }

  testWidgets('칼로리 축은 0 기준선 위에 1,500·2,500 두 눈금만 그린다', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(
      <String>[for (final label in axisLabels(tester)) label.text],
      <String>['2,500', '1,500', '0'],
    );
  });

  testWidgets('세 지표 모두 맨 아래 눈금이 0 이다 (#548)', (WidgetTester tester) async {
    await pumpHome(tester);

    for (final String tab in <String>['칼로리', '나트륨', '당류']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();

      expect(
        axisLabels(tester).last.text,
        '0',
        reason: '$tab 축의 맨 아래 눈금이 0 이 아니다',
      );
    }
  });

  testWidgets('지표를 바꿔도 축 라벨끼리 겹치지 않는다', (WidgetTester tester) async {
    await pumpHome(tester);

    for (final String tab in <String>['칼로리', '나트륨', '당류']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();

      final List<({String text, Rect rect})> labels = axisLabels(tester);
      expect(labels.length, greaterThan(1), reason: '$tab 축에 눈금이 없다');
      for (int i = 1; i < labels.length; i++) {
        expect(
          labels[i].rect.top,
          greaterThanOrEqualTo(labels[i - 1].rect.bottom),
          reason:
              '$tab 축: "${labels[i - 1].text}" 와 "${labels[i].text}" 가 겹친다',
        );
      }
    }
  });
}
