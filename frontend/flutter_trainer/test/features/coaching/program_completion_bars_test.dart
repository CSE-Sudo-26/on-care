import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays;
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';

import '../../helpers/client_factory.dart';
import '../../helpers/pump_app.dart';

/// 프로그램 탭의 운동 이행률을 막대로 그린다. (#899)
///
/// 숫자만 적혀 있으면 목록을 훑으며 누가 처지는지 견주려고 눈으로 비교해야
/// 한다. 요약 카드에는 이 회원의 한 주가 어떻게 흘렀는지가 아예 없었다.
void main() {
  Future<void> openCoaching(
    WidgetTester tester,
    List<TrainerClient> roster,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.coaching,
      extraOverrides: <Override>[
        clientsProvider.overrideWith(
          (ref) => Stream<List<TrainerClient>>.value(roster),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Finder rowBar(String id) => find.descendant(
    of: find.byKey(ValueKey<String>('program-client-$id')),
    matching: find.byType(InlineBarValue),
  );

  /// 이행률 막대가 실제로 칠해진 색. 채워진 쪽(`FractionallySizedBox` 안의
  /// `Container`)만 본다 — 트랙은 늘 회색이다.
  Color barFill(WidgetTester tester, String id) => (tester
              .widget<Container>(
                find.descendant(
                  of: find.descendant(
                    of: rowBar(id),
                    matching: find.byType(FractionallySizedBox),
                  ),
                  matching: find.byType(Container),
                ),
              )
              .color) ??
      const Color(0x00000000);

  testWidgets('회원 목록 행의 이행률이 막대와 값으로 함께 보인다', (tester) async {
    await openCoaching(tester, <TrainerClient>[
      makeClient(
        id: 'steady',
        name: '꾸준고객',
        weekCompletion: const <int>[90, 90, 90, 90, 90, 90, 90],
      ),
    ]);

    final bar = tester.widget<InlineBarValue>(rowBar('steady'));
    expect(bar.fraction, closeTo(0.9, 0.001));
    expect(bar.text, '90%');
    expect(barFill(tester, 'steady'), AppColors.primary);
  });

  testWidgets('이행률이 낮아도 막대는 남색이다 (#913)', (tester) async {
    await openCoaching(tester, <TrainerClient>[
      makeClient(
        id: 'slipping',
        name: '처지는고객',
        weekCompletion: const <int>[40, 40, 40, 40, 40, 40, 40],
      ),
    ]);

    // 빨강은 이 앱에서 `목표 초과` 다(#690). 이행률이 낮은 것은 초과가
    // 아니라 아직 덜 한 것이고, 그 사실은 길이와 값이 이미 말한다.
    expect(barFill(tester, 'slipping'), AppColors.primary);
    expect(barFill(tester, 'slipping'), isNot(AppColors.overTarget));

    final Color valueColor = tester
        .widget<Text>(
          find.descendant(of: rowBar('slipping'), matching: find.text('40%')),
        )
        .style!
        .color!;
    expect(valueColor, AppColors.primary);
  });

  testWidgets('기록이 없는 회원은 막대를 그리지 않는다', (tester) async {
    await openCoaching(tester, <TrainerClient>[
      makeClient(
        id: 'blank',
        name: '기록없음',
        weekCompletion: const <int>[0, 0, 0, 0, 0, 0, 0],
      ),
    ]);

    final bar = tester.widget<InlineBarValue>(rowBar('blank'));
    expect(bar.fraction, isNull, reason: '기록 없음이 0% 수행으로 읽힌다');
    // 왜 빈지를 적는다 — `-` 만으로는 값이 0 인지 없는지 알 수 없다.
    expect(bar.text, '데이터 부족');
    expect(
      find.descendant(of: rowBar('blank'), matching: find.text('데이터 부족')),
      findsOneWidget,
    );
  });

  testWidgets('기록이 없는 줄은 라벨까지 흐려진다', (tester) async {
    await openCoaching(tester, <TrainerClient>[
      makeClient(
        id: 'blank',
        name: '기록없음',
        weekCompletion: const <int>[0, 0, 0, 0, 0, 0, 0],
      ),
    ]);

    Color colorOf(String text) => tester
        .widget<Text>(
          find.descendant(of: rowBar('blank'), matching: find.text(text)),
        )
        .style!
        .color!;

    // 값 칸만 흐리면 라벨은 또렷한 채로 남아, 잴 값이 있는데 못 읽은 것처럼
    // 보인다. 줄 전체가 흐려져야 읽거나 누를 것이 없다는 뜻이 된다.
    expect(colorOf('데이터 부족'), AppColors.disabledForeground);
    expect(colorOf('운동 이행률'), AppColors.disabledForeground);
  });

  testWidgets('회원 요약 카드에 요일별 이행률 막대그래프가 보인다', (tester) async {
    const week = <int>[80, 0, 90, 70, 60, 50, 40];
    await openCoaching(tester, <TrainerClient>[
      makeClient(id: 'week', name: '주간고객', weekCompletion: week),
    ]);

    final chart = tester.widget<BarSeriesChart>(
      find.byKey(const ValueKey<String>('program-week-completion-chart')),
    );
    expect(chart.values, week);
    expect(chart.maxValue, 100);
    expect(chart.valueSuffix, '%');
    // 아직 오지 않은 요일은 빈 트랙이다 — 0% 수행과 구분한다.
    expect(chart.pendingFromIndex, elapsedWeekdays(nowKst()));
    // 지난 날인데 기록이 없는 요일도 0% 가 아니다. 화요일(index 1)이 그렇다.
    final elapsed = elapsedWeekdays(nowKst());
    expect(chart.missingIndices.contains(1), elapsed > 1);
  });

  testWidgets('주간 계열이 없는 회원은 그래프 자리에 안내가 뜬다', (tester) async {
    await openCoaching(tester, <TrainerClient>[
      makeClient(id: 'short', name: '짧은계열', weekCompletion: const <int>[80]),
    ]);

    expect(
      find.byKey(const ValueKey<String>('program-week-completion-chart')),
      findsNothing,
    );
    expect(find.text('이번 주 운동 기록이 없어요'), findsWidgets);
  });
}
