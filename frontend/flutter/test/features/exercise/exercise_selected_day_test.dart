import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/pages/exercise_page.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/repositories/member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const List<String> _dayLabels = <String>['월', '화', '수', '목', '금', '토', '일'];

/// 요일마다 [minutes] 분씩 채운 주. 0 을 주면 기록이 없는 주가 된다.
ExerciseWeek _week(double minutes) {
  final List<double> daily = List<double>.filled(7, minutes);
  return ExerciseWeek(
    sessions: <ExerciseSession>[
      if (minutes > 0)
        for (final String d in _dayLabels)
          ExerciseSession(
            id: 'x-$d',
            dayLabel: d,
            type: ExerciseType.cardio,
            minutes: minutes.round(),
            calories: minutes.round() * 7,
          ),
    ],
    dailyMinutes: daily,
    dailyCalories: List<double>.filled(7, minutes * 7),
    cardioMinutes: daily,
    strengthMinutes: List<double>.filled(7, 0),
    stretchingMinutes: List<double>.filled(7, 0),
    dayLabels: _dayLabels,
    totalMinutes: (minutes * 7).round(),
    totalCalories: (minutes * 49).round(),
    streakDays: minutes > 0 ? 7 : 0,
    aiCoachMessage: '',
  );
}

/// 모든 주가 같은 값인 저장소. 어느 날짜를 골라도 기록이 있다.
class _FixedWeekRepository implements ExerciseRepository {
  _FixedWeekRepository(this.minutes);
  final double minutes;

  @override
  Future<ExerciseWeek> fetchThisWeek() async => _week(minutes);

  @override
  Future<ExerciseWeek> fetchWeek(DateTime weekStart) async => _week(minutes);

  @override
  Future<ExerciseSession> addSession({
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSession(String id) async => throw UnimplementedError();

  @override
  Future<ExerciseSession> updateSession({
    required String id,
    required ExerciseType type,
    required int minutes,
    required int calories,
    required String dayLabel,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
  }) async => throw UnimplementedError();
}

Widget _app(ExerciseRepository repo) {
  return ProviderScope(
    overrides: <Override>[
      // 데모 설정 — _PtLogCard 등 하위 카드가 실서버 provider 를 타지 않는다.
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: Environment.dev,
          apiBaseUrl: 'https://example.test',
          useMockApi: true,
        ),
      ),
      exerciseRepositoryProvider.overrideWithValue(repo),
      accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
      memberCoachRepositoryProvider.overrideWithValue(
        MockMemberCoachRepository() as MemberCoachRepository,
      ),
    ],
    child: const MaterialApp(
      locale: Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExercisePage(),
    ),
  );
}

/// 오늘이 아니면서 **이번 주 안에** 있고 주간 스트립(오늘 ±3일)에 보이는 날짜.
DateTime _otherDayThisWeek() {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  // 월요일이면 어제가 지난 주로 넘어가므로 내일을 고른다. 그 밖에는 어제.
  return today.weekday == DateTime.monday
      ? today.add(const Duration(days: 1))
      : today.subtract(const Duration(days: 1));
}

void main() {
  testWidgets('오늘이 아닌 날에 기록이 있으면 빈 문구 대신 그날 요약을 그린다 (#671)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_FixedWeekRepository(40)));
    await tester.pumpAndSettle();

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(ExercisePage)),
    );
    final DateTime target = _otherDayThisWeek();

    await tester.tap(find.text('${target.day}').first);
    await tester.pumpAndSettle();

    expect(
      find.text(l.otherDateEmpty(l.pageExerciseTitle)),
      findsNothing,
      reason: '기록이 있는 날인데 빈 문구가 나오면 안 된다',
    );
    expect(
      find.text('${target.month}월 ${target.day}일 ${l.pageExerciseTitle}'),
      findsOneWidget,
    );
    // 유형별 분해에 그날의 유산소 40분이 보인다.
    expect(find.text('40${l.unitMinutes}'), findsWidgets);
  });

  testWidgets('정말 기록이 없는 날에는 빈 문구가 그대로 나온다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_FixedWeekRepository(0)));
    await tester.pumpAndSettle();

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(ExercisePage)),
    );
    final DateTime target = _otherDayThisWeek();

    await tester.tap(find.text('${target.day}').first);
    await tester.pumpAndSettle();

    expect(find.text(l.otherDateEmpty(l.pageExerciseTitle)), findsOneWidget);
  });
}
