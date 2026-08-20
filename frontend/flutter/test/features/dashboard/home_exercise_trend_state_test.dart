/// 홈 운동 카드 주간 추이의 세 상태 (#962).
///
/// 예전에는 값이 없으면 데모 상수 막대를 그렸다. `valueOrNull` 이 로딩과 에러를
/// 똑같이 `null` 로 주기 때문에, 실 API 가 실패한 동안에도 "이만큼 태웠다" 는
/// 막대가 오류 표시 없이 남았다. 세 상태가 각각 다른 것을 그리는지 못박는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

void main() {
  const DashboardSummary summary = DashboardSummary(
    indicators: <HealthIndicator>[
      HealthIndicator(label: '칼로리', current: 1860, max: 2000, unit: 'kcal'),
      HealthIndicator(label: '나트륨', current: 2329, max: 2000, unit: 'mg'),
      HealthIndicator(label: '당류', current: 43, max: 50, unit: 'g'),
    ],
    macros: DietMacros.zero(),
    dietEntries: 4,
    exerciseMinutes: 45,
    exerciseCalories: 520,
    exerciseCount: 4,
    todaySchedule: <ScheduleItem>[],
    weekScore: 85,
    weekScoreDelta: 12,
    sodiumWarning: null,
  );

  final Finder chart = find.byKey(
    const ValueKey<String>('dashboard-exercise-chart'),
  );
  final Finder error = find.byKey(
    const ValueKey<String>('dashboard-exercise-chart-error'),
  );
  final Finder loading = find.byKey(
    const ValueKey<String>('dashboard-exercise-chart-loading'),
  );

  Future<void> pumpHome(
    WidgetTester tester,
    AsyncValue<ExerciseWeek> week,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          accountRepositoryProvider.overrideWithValue(
            MockAccountRepository(),
          ),
          dashboardSummaryProvider.overrideWith((ref) async => summary),
          memberCoachRepositoryProvider.overrideWithValue(
            MockMemberCoachRepository(),
          ),
          exerciseWeekViewProvider.overrideWithValue(week),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DashboardContent()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  ExerciseWeek weekWith(List<double> daily) => ExerciseWeek(
    sessions: const <ExerciseSession>[],
    dailyMinutes: const <double>[0, 0, 0, 0, 0, 0, 0],
    dayLabels: const <String>['월', '화', '수', '목', '금', '토', '일'],
    totalMinutes: 45,
    totalCalories: 520,
    streakDays: 2,
    aiCoachMessage: '',
    dailyCalories: daily,
  );

  testWidgets('불러오지 못하면 막대 대신 실패를 말한다', (WidgetTester tester) async {
    await pumpHome(
      tester,
      AsyncValue<ExerciseWeek>.error(Exception('boom'), StackTrace.empty),
    );

    expect(error, findsOneWidget);
    expect(chart, findsNothing);
    expect(find.text('주간 운동 기록을 불러오지 못했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('실패 상태에서 다시 시도를 누를 수 있다', (WidgetTester tester) async {
    await pumpHome(
      tester,
      AsyncValue<ExerciseWeek>.error(Exception('boom'), StackTrace.empty),
    );

    final Finder retry = find.byKey(
      const ValueKey<String>('dashboard-exercise-chart-retry'),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('읽는 중에는 자리만 잡고 막대를 그리지 않는다', (WidgetTester tester) async {
    await pumpHome(tester, const AsyncValue<ExerciseWeek>.loading());

    expect(loading, findsOneWidget);
    expect(chart, findsNothing);
    expect(error, findsNothing);
  });

  testWidgets('기록이 없는 주는 빈 차트를 그린다', (WidgetTester tester) async {
    await pumpHome(
      tester,
      AsyncValue<ExerciseWeek>.data(
        weekWith(const <double>[0, 0, 0, 0, 0, 0, 0]),
      ),
    );

    expect(chart, findsOneWidget);
    expect(error, findsNothing);
    expect(loading, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('값이 있으면 그 값을 그린다', (WidgetTester tester) async {
    await pumpHome(
      tester,
      AsyncValue<ExerciseWeek>.data(
        weekWith(const <double>[100, 200, 300, 400, 500, 600, 700]),
      ),
    );

    expect(chart, findsOneWidget);
    expect(error, findsNothing);
  });

  group('series', () {
    test('일곱 칸으로 맞추고 아직 오지 않은 요일은 비운다', () {
      expect(
        exerciseTrendSeriesForTest(
          const <double>[10, 20, 30, 40, 50, 60, 70],
          2,
        ),
        <double>[10, 20, 30, 0, 0, 0, 0],
      );
    });

    test('모자라는 응답도 일곱 칸이 된다', () {
      expect(
        exerciseTrendSeriesForTest(const <double>[10, 20], 6),
        <double>[10, 20, 0, 0, 0, 0, 0],
      );
    });

    test('빈 응답은 전부 0 이다', () {
      expect(
        exerciseTrendSeriesForTest(const <double>[], 6),
        <double>[0, 0, 0, 0, 0, 0, 0],
      );
    });
  });
}
