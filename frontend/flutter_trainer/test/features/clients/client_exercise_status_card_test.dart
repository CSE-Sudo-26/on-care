import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_exercise_status_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_period_section.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/activity_charts.dart';

/// 고객 운동 현황은 회원 앱 `운동 현황` 과 **같은 그림**이다. (#943)
///
/// `오늘` 은 도넛 + 유형별 시간, 기간은 유형별 3색 누적 막대. 예전에는 트레이너만
/// 한 색 막대를 봤다 — 회원이 "이번 주 근력이 적었죠" 라고 말해도 근거가 없었다.
ClientExercisePeriod _fixture(
  ClientPeriodKey key, {
  required List<int> cardio,
  required List<int> strength,
  required List<int> stretch,
}) {
  final List<DateTime> dates = clientRangeDates(
    clientRangeFor(key.period, key.day),
  );
  int at(List<int> xs, int i) => i < xs.length ? xs[i] : 0;
  return ClientExercisePeriod(
    range: clientRangeFor(key.period, key.day),
    days: <ClientExerciseDay>[
      for (int i = 0; i < dates.length; i++)
        ClientExerciseDay(
          date: dates[i],
          minutes: at(cardio, i) + at(strength, i) + at(stretch, i),
          calories: (at(cardio, i) + at(strength, i) + at(stretch, i)) * 6,
          cardioMinutes: at(cardio, i),
          strengthMinutes: at(strength, i),
          stretchingMinutes: at(stretch, i),
        ),
    ],
  );
}

/// 카드를 섹션 헤더와 함께 띄운다 — 실제 화면과 같은 조합이다.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  ClientPeriod _period = ClientPeriod.today;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClientPeriodSection(
          title: '운동 현황',
          period: _period,
          onChanged: (ClientPeriod p) => setState(() => _period = p),
          child: ClientExerciseStatusCard(clientId: 'c1', period: _period),
        ),
      ),
    ),
  );
}

Widget _app(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    locale: Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _Host(),
  ),
);

void main() {
  List<Override> withSplit() => <Override>[
    clientExercisePeriodProvider.overrideWith(
      (ref, key) async => _fixture(
        key,
        cardio: const <int>[20, 0, 30, 0, 10, 0, 0],
        strength: const <int>[25, 0, 15, 0, 30, 0, 0],
        stretch: const <int>[15, 0, 0, 0, 20, 0, 0],
      ),
    ),
  ];

  Future<void> pump(WidgetTester tester, List<Override> overrides) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(overrides));
    await tester.pumpAndSettle();
  }

  testWidgets('오늘은 도넛과 유형별 시간으로 보인다', (tester) async {
    await pump(tester, withSplit());

    expect(find.byType(ActivityDonut), findsOneWidget);
    expect(find.text('오늘 총 운동 시간'), findsOneWidget);
    // 유산소·근력·스트레칭이 이름과 분으로 함께 읽힌다 — 60분이 무엇으로
    // 채워졌는지가 화면에 있어야 한다.
    for (final String label in <String>['유산소', '근력', '스트레칭']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // 기간 막대는 오늘에 없다.
    expect(find.byType(ActivityBarChart), findsNothing);
  });

  testWidgets('기간은 유형별 3색 누적 막대로 보인다', (tester) async {
    await pump(tester, withSplit());

    await tester.tap(find.byKey(const Key('client-period-week')));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityBarChart), findsOneWidget);
    expect(find.byType(ActivityDonut), findsNothing);
    // 막대 하나마다 hover 영역이 하나.
    expect(find.byKey(const Key('activity-bar-0')), findsOneWidget);
    expect(find.byKey(const Key('activity-bar-6')), findsOneWidget);
    expect(find.byKey(const Key('activity-bar-7')), findsNothing);
    // 범례 셋이 회원 앱과 같은 순서·색이다.
    final List<ActivityLegend> legends = tester
        .widgetList<ActivityLegend>(find.byType(ActivityLegend))
        .toList();
    expect(legends.map((ActivityLegend x) => x.color).toList(), <Color>[
      AppColors.chartCardio,
      AppColors.chartStrength,
      AppColors.chartStretching,
    ]);
  });

  testWidgets('막대 툴팁이 유형별 분을 말한다', (tester) async {
    await pump(tester, withSplit());
    await tester.tap(find.byKey(const Key('client-period-week')));
    await tester.pumpAndSettle();

    final Tooltip tip = tester.widget<Tooltip>(
      find.byKey(const Key('activity-bar-0')),
    );
    final String text = tip.richMessage!.toPlainText();
    expect(text, contains('유산소'));
    expect(text, contains('20분'));
    expect(text, contains('근력'));
    expect(text, contains('25분'));
    expect(text, contains('스트레칭'));
    expect(text, contains('15분'));

    // 기록이 없는 날은 `기록 없음` 이다 — 0분이라고 적으면 쉰 날과 구분되지 않는다.
    final Tooltip rest = tester.widget<Tooltip>(
      find.byKey(const Key('activity-bar-1')),
    );
    expect(rest.richMessage!.toPlainText(), contains('기록 없음'));
  });

  testWidgets('기간을 바꿔도 토글 자리가 움직이지 않는다', (tester) async {
    await pump(tester, withSplit());

    Rect toggleRect() => tester.getRect(
      find.byKey(const ValueKey<String>('client-period-toggle')),
    );

    final Rect atToday = toggleRect();
    await tester.tap(find.byKey(const Key('client-period-week')));
    await tester.pumpAndSettle();
    final Rect atWeek = toggleRect();
    await tester.tap(find.byKey(const Key('client-period-month')));
    await tester.pumpAndSettle();
    final Rect atMonth = toggleRect();

    // 카드 제목 줄에 얹었을 때는 카드가 갈리며 제목 길이가 달라져 토글이
    // 좌우로 움직였다. 헤더는 기간과 무관하게 늘 같은 것을 그린다.
    expect(atWeek, atToday);
    expect(atMonth, atToday);
  });

  testWidgets('유형 분해가 없으면 지어내지 않고 유산소로 둔다', (tester) async {
    await pump(tester, <Override>[
      clientExercisePeriodProvider.overrideWith(
        (ref, key) async => ClientExercisePeriod(
          range: clientRangeFor(key.period, key.day),
          days: <ClientExerciseDay>[
            for (final DateTime d in clientRangeDates(
              clientRangeFor(key.period, key.day),
            ))
              ClientExerciseDay(date: d, minutes: 40, calories: 240),
          ],
        ),
      ),
    ]);

    await tester.tap(find.byKey(const Key('client-period-week')));
    await tester.pumpAndSettle();

    final Tooltip tip = tester.widget<Tooltip>(
      find.byKey(const Key('activity-bar-0')),
    );
    final String text = tip.richMessage!.toPlainText();
    expect(text, contains('유산소'));
    // 없는 근력·스트레칭 시간을 지어내면 안 된다.
    expect(text, isNot(contains('근력')));
    expect(text, isNot(contains('스트레칭')));
  });

  testWidgets('폭 1024 · 영어 · 배율 1.3 에서도 토글이 제자리고 넘치지 않는다', (tester) async {
    // #849 가 지키는 가장 좁은 지원 조합. 기간을 바꿔도 헤더가 흔들리지 않아야
    // 하고, 카드가 화면 밖으로 나가면 안 된다.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: withSplit(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const _Host(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Rect toggleRect() => tester.getRect(
      find.byKey(const ValueKey<String>('client-period-toggle')),
    );
    final Rect atToday = toggleRect();

    for (final String period in <String>['week', 'month']) {
      await tester.tap(find.byKey(Key('client-period-$period')));
      await tester.pumpAndSettle();
      expect(toggleRect(), atToday, reason: period);
      expect(tester.takeException(), isNull, reason: period);
      // 카드가 가로로 넘치지 않는다.
      final Rect card = tester.getRect(
        find.byKey(const ValueKey<String>('client-exercise-status-card')),
      );
      expect(card.right, lessThanOrEqualTo(1024.0 + 0.5), reason: period);
    }
  });

  testWidgets('길이가 짧은 유형 배열이 와도 죽지 않는다 (리뷰 #946)', (tester) async {
    // `hasTypeSplit` 은 셋의 길이가 서로 같은지만 본다. 기간 provider 의 루프는
    // 언제나 7일을 도는데, 길이 2짜리 응답이 분해로 인정되면 d == 2 에서 범위를
    // 넘어 화면이 통째로 죽는다.
    await pump(tester, <Override>[
      clientExercisePeriodProvider.overrideWith((ref, key) async {
        final List<DateTime> dates = clientRangeDates(
          clientRangeFor(key.period, key.day),
        );
        return ClientExercisePeriod(
          range: clientRangeFor(key.period, key.day),
          days: <ClientExerciseDay>[
            for (int i = 0; i < dates.length; i++)
              ClientExerciseDay(
                date: dates[i],
                minutes: i < 2 ? 30 : 0,
                calories: i < 2 ? 180 : 0,
                cardioMinutes: i < 2 ? 30 : 0,
              ),
          ],
        );
      }),
    ]);

    await tester.tap(find.byKey(const Key('client-period-week')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ActivityBarChart), findsOneWidget);
  });

  test('유형 분해는 길이가 맞을 때만 쓴다', () {
    // 반쪽만 실려 온 응답으로 쌓으면 막대가 실제보다 낮아 보인다.
    const ClientExerciseWeek short = ClientExerciseWeek(
      dayLabels: <String>['월', '화'],
      dailyMinutes: <int>[30, 20],
      dailyCalories: <int>[180, 120],
      cardioMinutes: <int>[30],
      totalMinutes: 50,
      totalCalories: 300,
    );
    expect(short.hasTypeSplit, isFalse);

    const ClientExerciseWeek full = ClientExerciseWeek(
      dayLabels: <String>['월', '화'],
      dailyMinutes: <int>[30, 20],
      dailyCalories: <int>[180, 120],
      cardioMinutes: <int>[20, 10],
      strengthMinutes: <int>[10, 5],
      stretchingMinutes: <int>[0, 5],
      totalMinutes: 50,
      totalCalories: 300,
    );
    expect(full.hasTypeSplit, isTrue);
  });

  test('오늘 기준 키는 KST 를 쓴다', () {
    expect(clientPeriodKeyNow('c1', ClientPeriod.today).day, todayKst());
  });
}
