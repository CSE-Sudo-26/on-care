import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/weekly_exercise_trend_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

/// 고정된 기간 데이터. 요청한 기간의 날짜 수만큼 [minutes]·[calories] 를
/// 앞에서부터 채운다 — 남는 날은 기록이 없는 날이다.
ClientExercisePeriod _period(
  ClientPeriod period, {
  required List<int> minutes,
  required List<int> calories,
}) {
  final ClientDateRange range = clientRangeNow(period);
  final List<DateTime> dates = clientRangeDates(range);
  return ClientExercisePeriod(
    range: range,
    days: <ClientExerciseDay>[
      for (int i = 0; i < dates.length; i++)
        ClientExerciseDay(
          date: dates[i],
          minutes: i < minutes.length ? minutes[i] : 0,
          calories: i < calories.length ? calories[i] : 0,
        ),
    ],
  );
}

Widget _app({required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    // 카드 문구가 l10n 에서 오므로 로케일을 고정한다 — 비워 두면 실행
    // 환경의 시스템 로케일에 따라 영어로 그려진다.
    locale: Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: WeeklyExerciseTrendCard(clientId: 'c1'),
      ),
    ),
  ),
);

void main() {
  test('counts every session when multiple workouts occur on one day', () {
    final week = ClientExerciseWeek.fromJson(<String, Object?>{
      'day_labels': <String>['월'],
      'daily_minutes': <int>[60],
      'daily_calories': <int>[420],
      'total_minutes': 60,
      'total_calories': 420,
      'sessions': <Object?>[
        <String, Object?>{'duration_minutes': 30},
        <String, Object?>{'duration_minutes': 30},
      ],
    });

    expect(week.workoutCount, 2);
  });

  testWidgets('오늘이 기본이고, 이번 주로 옮기면 일별 추이가 보인다 (#914)', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        overrides: <Override>[
          clientExercisePeriodProvider.overrideWith(
            (ref, key) async => _period(
              key.period,
              minutes: key.period == ClientPeriod.today
                  ? const <int>[40]
                  : const <int>[30, 0, 45, 0, 60, 0, 0],
              calories: key.period == ClientPeriod.today
                  ? const <int>[240]
                  : const <int>[180, 0, 270, 0, 360, 0, 0],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 기본은 오늘 — 식단 카드와 첫 화면의 기준을 맞춘다.
    expect(find.text('운동 추이'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^40 '), findRichText: true),
      findsOneWidget,
    );
    // 오늘에는 '운동한 날' 도, 일별 막대도 없다.
    expect(find.text('운동한 날'), findsNothing);
    expect(find.byKey(const Key('client-exercise-bar-0')), findsNothing);

    await tester.tap(find.byKey(const Key('client-period-week')));
    await tester.pumpAndSettle();

    expect(find.text('운동한 날'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^135 '), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'^810 '), findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('client-exercise-bar-0')), findsOneWidget);
  });

  testWidgets('이번 달을 고르면 그 달 날짜 수만큼 막대가 그려진다 (#914)', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        overrides: <Override>[
          clientExercisePeriodProvider.overrideWith(
            (ref, key) async => _period(
              key.period,
              minutes: const <int>[30, 0, 45],
              calories: const <int>[180, 0, 270],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('client-period-month')));
    await tester.pumpAndSettle();

    final int days = clientRangeDates(
      clientRangeNow(ClientPeriod.month),
    ).length;
    expect(find.byKey(Key('client-exercise-bar-${days - 1}')), findsOneWidget);
    expect(find.byKey(Key('client-exercise-bar-$days')), findsNothing);
  });

  testWidgets('칼로리 계열은 주황이 아니라 연한 남색이다 (#914)', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        overrides: <Override>[
          clientExercisePeriodProvider.overrideWith(
            (ref, key) async => _period(
              key.period,
              minutes: const <int>[30, 0, 45, 0, 60, 0, 0],
              calories: const <int>[180, 0, 270, 0, 360, 0, 0],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('client-period-week')));
    await tester.pumpAndSettle();

    Color fillOf(int index) =>
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byKey(Key('client-exercise-bar-$index')),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;

    expect(fillOf(0), AppColors.primary.withValues(alpha: 0.82));

    await tester.tap(find.text('칼로리'));
    await tester.pumpAndSettle();

    // 트레이너 앱은 남색 브랜드에 주황을 작은 강조로만 쓴다. 그래프 전체가
    // 주황이면 이 계열만 튀고, 많이 탄 좋은 날이 경고처럼 보인다.
    expect(fillOf(0), AppColors.aiCardGradientEnd.withValues(alpha: 0.82));
    expect(fillOf(0), isNot(AppColors.brandOrange.withValues(alpha: 0.82)));
    expect(find.text('180kcal'), findsOneWidget);
    expect(find.text('360kcal'), findsOneWidget);
  });

  testWidgets('retries only when the error action is pressed', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      _app(
        overrides: <Override>[
          clientExercisePeriodProvider.overrideWith((ref, key) async {
            loads++;
            throw Exception('network');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);

    await tester.tap(
      find.byKey(const ValueKey<String>('weekly-exercise-retry')),
    );
    await tester.pumpAndSettle();
    expect(loads, 2);
  });

  test('기간 범위는 오늘·이번 주·이번 달을 각각 덮는다', () {
    final DateTime day = DateTime(2026, 8, 19); // 수요일
    expect(clientRangeFor(ClientPeriod.today, day).from, DateTime(2026, 8, 19));
    expect(clientRangeFor(ClientPeriod.today, day).to, DateTime(2026, 8, 19));
    expect(clientRangeFor(ClientPeriod.week, day).from, DateTime(2026, 8, 17));
    expect(clientRangeFor(ClientPeriod.week, day).to, DateTime(2026, 8, 23));
    expect(clientRangeFor(ClientPeriod.month, day).from, DateTime(2026, 8));
    expect(clientRangeFor(ClientPeriod.month, day).to, DateTime(2026, 8, 31));

    // 12월은 다음 해로 새지 않는다.
    expect(
      clientRangeFor(ClientPeriod.month, DateTime(2026, 12, 15)).to,
      DateTime(2026, 12, 31),
    );
    // 한 달은 걸친 주를 모두 읽어야 그려진다.
    expect(
      clientRangeWeekStarts(
        clientRangeFor(ClientPeriod.month, DateTime(2026, 8, 19)),
      ),
      <DateTime>[
        DateTime(2026, 7, 27),
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 31),
      ],
    );
    // 오늘 기준 범위는 KST 를 쓴다 — 기기 타임존을 섞으면 하루가 밀린다.
    expect(
      clientRangeNow(ClientPeriod.today).from,
      DateTime(nowKst().year, nowKst().month, nowKst().day),
    );
  });
}
