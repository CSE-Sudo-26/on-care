import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import 'package:oncare/app/app.dart';
import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/app/session_feature_reset.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:oncare/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/services/locale_provider.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    const config = AppConfig(
      environment: Environment.dev,
      apiBaseUrl: 'https://dev.api.test',
      useMockApi: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(config),
          appLoggerProvider.overrideWithValue(Logger(level: Level.off)),
          // Diet repo defaults to DioDietRepository (Stage 9) which
          // needs a real dio+db. Swap to the in-memory mock here.
          dietRepositoryProvider.overrideWithValue(
            MockDietRepository() as DietRepository,
          ),
          // Same reason — exercise repo defaults to DioExerciseRepository
          // (Stage 9.6); swap to the in-memory mock here.
          exerciseRepositoryProvider.overrideWithValue(
            MockExerciseRepository() as ExerciseRepository,
          ),
          // Dashboard summary defaults to DioDashboardRepository (Stage
          // 9.8); the smoke test only inspects the nav, so the mock is
          // plenty.
          dashboardRepositoryProvider.overrideWithValue(
            MockDashboardRepository(MockDietRepository())
                as DashboardRepository,
          ),
          sessionFeatureResetOverride(),
          if (locale != null) localeProvider.overrideWith((ref) => locale),
        ],
        child: const OncareApp(),
      ),
    );
    await tester.pumpAndSettle();
    // The app now boots into the sign-in screen; enter demo mode to reach
    // the main app (Home tab). Find by Key so the finder is locale-independent,
    // and scroll it into view (it sits below the fold on the compact surface).
    final demoButton = find.byKey(const Key('demoEnterButton'));
    await tester.ensureVisible(demoButton);
    await tester.pumpAndSettle();
    await tester.tap(demoButton);
    await tester.pumpAndSettle();
  }

  GoRouter appRouter(WidgetTester tester) {
    return ProviderScope.containerOf(
      tester.element(find.byType(OncareApp)),
    ).read(appRouterProvider);
  }

  Future<double> openRecordSheetAndMeasureBottomSpacing(
    WidgetTester tester,
  ) async {
    await tester.tap(find.byKey(const Key('recordAddButton')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('recordAddSheet'));
    final options = find.byKey(const Key('recordOptions'));

    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getBottomRight(sheet).dy, logicalHeight);

    return tester.getBottomRight(sheet).dy - tester.getBottomRight(options).dy;
  }

  double bottomSpacingBetween(
    WidgetTester tester,
    String surfaceKey,
    String contentKey,
  ) {
    return tester.getBottomRight(find.byKey(Key(surfaceKey))).dy -
        tester.getBottomRight(find.byKey(Key(contentKey))).dy;
  }

  Future<void> openExerciseAddSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('recordAddButton')));
    await tester.pumpAndSettle();
    final exerciseOption = find.descendant(
      of: find.byKey(const Key('recordOptions')),
      matching: find.text('운동'),
    );
    await tester.tap(exerciseOption);
    await tester.pumpAndSettle();
  }

  testWidgets('Enters the Home tab in English after demo', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    // Bottom-nav labels match the React original.
    expect(find.text('Home'), findsAtLeastNWidgets(1));
    expect(find.text('Diet'), findsAtLeastNWidgets(1));
    expect(find.text('Exercise'), findsAtLeastNWidgets(1));
    expect(find.text('MY'), findsAtLeastNWidgets(1));
  });

  testWidgets('record sheet has no fixed bottom gap without a system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, locale: const Locale('ko'));

    final bottomSpacing = await openRecordSheetAndMeasureBottomSpacing(tester);

    expect(bottomSpacing, 0);
  });

  testWidgets('record sheet keeps only the required system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await pumpApp(tester, locale: const Locale('ko'));

    final bottomSpacing = await openRecordSheetAndMeasureBottomSpacing(tester);

    expect(bottomSpacing, 34);
  });

  testWidgets('diet add opens as a content-sized sheet without a bottom gap', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('ko'));
    await tester.tap(find.byKey(const Key('recordAddButton')));
    await tester.pumpAndSettle();

    final dietOption = find.descendant(
      of: find.byKey(const Key('recordOptions')),
      matching: find.text('식단'),
    );
    await tester.tap(dietOption);
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('dietAddSheet'));
    final options = find.byKey(const Key('dietAddOptions'));
    expect(sheet, findsOneWidget);
    expect(tester.getTopLeft(sheet).dy, greaterThan(0));
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getBottomRight(sheet).dy, logicalHeight);
    expect(
      tester.getBottomRight(sheet).dy - tester.getBottomRight(options).dy,
      0,
    );
    expect(find.byKey(const Key('recordAddSheet')), findsNothing);
  });

  testWidgets('exercise add has no fixed bottom gap without a system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, locale: const Locale('ko'));
    await openExerciseAddSheet(tester);

    expect(
      bottomSpacingBetween(tester, 'exerciseAddSheet', 'exerciseAddContent'),
      0,
    );
  });

  testWidgets('exercise add keeps only the required system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await pumpApp(tester, locale: const Locale('ko'));
    await openExerciseAddSheet(tester);

    expect(
      bottomSpacingBetween(tester, 'exerciseAddSheet', 'exerciseAddContent'),
      34,
    );
  });

  testWidgets('coaching sheet has no fixed bottom gap without a system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, locale: const Locale('ko'));
    await tester.tap(find.byKey(const Key('coachingFab')));
    await tester.pumpAndSettle();

    expect(
      bottomSpacingBetween(tester, 'coachingSheet', 'coachingSheetCta'),
      0,
    );
  });

  testWidgets('coaching sheet keeps only the required system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await pumpApp(tester, locale: const Locale('ko'));
    await tester.tap(find.byKey(const Key('coachingFab')));
    await tester.pumpAndSettle();

    expect(
      bottomSpacingBetween(tester, 'coachingSheet', 'coachingSheetCta'),
      34,
    );
  });

  testWidgets('header notification opens the existing full page', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('ko'));

    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await tester.pumpAndSettle();

    final page = find.byKey(const Key('notificationPage'));
    expect(page, findsOneWidget);
    expect(tester.getTopLeft(page).dy, 0);
  });

  testWidgets('point benefits use a full-page URL route', (tester) async {
    await pumpApp(tester, locale: const Locale('ko'));
    await tester.tap(find.text('MY').first);
    await tester.pumpAndSettle();

    final banner = find.byKey(const Key('pointsBanner'));
    await tester.ensureVisible(banner);
    await tester.tap(banner);
    await tester.pumpAndSettle();

    final page = find.byKey(const Key('pointsBenefitsPage'));
    expect(page, findsOneWidget);
    expect(
      appRouter(tester).routeInformationProvider.value.uri.path,
      AppRoutes.myPoints,
    );
  });

  testWidgets('MY settings use full-page URL routes', (tester) async {
    await pumpApp(tester, locale: const Locale('ko'));
    appRouter(tester).go(AppRoutes.mySettingsPath('support'));
    await tester.pumpAndSettle();

    final page = find.byKey(const Key('mySettingsPage'));
    expect(page, findsOneWidget);
    expect(
      appRouter(tester).routeInformationProvider.value.uri.path,
      AppRoutes.mySettingsPath('support'),
    );
  });

  testWidgets('diet detail URL restores the full-page editor', (tester) async {
    await pumpApp(tester, locale: const Locale('ko'));
    appRouter(tester).go(AppRoutes.dietEntryDetailPath('mock-breakfast'));
    await tester.pumpAndSettle();

    final page = find.byKey(const Key('mealDetailPage'));
    expect(page, findsOneWidget);
    expect(
      appRouter(tester).routeInformationProvider.value.uri.path,
      AppRoutes.dietEntryDetailPath('mock-breakfast'),
    );
  });

  testWidgets('Tapping a bottom-nav destination switches branch', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    // OncareHeader is a Material+Container (not an AppBar), so we
    // settle for `find.text(...)` finders here.
    await tester.tap(find.text('Diet').first);
    await tester.pumpAndSettle();
    expect(find.text('Diet'), findsAtLeastNWidgets(1));

    final exerciseDestination = find.ancestor(
      of: find.byIcon(Icons.fitness_center_outlined),
      matching: find.byType(InkWell),
    );
    await tester.tap(exerciseDestination);
    await tester.pumpAndSettle();
    expect(find.text('Exercise'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('MY').first);
    await tester.pumpAndSettle();
    expect(find.text('MY'), findsAtLeastNWidgets(1));
  });

  testWidgets('Monthly exercise status uses the daily bar chart', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    final exerciseDestination = find.ancestor(
      of: find.byIcon(Icons.fitness_center_outlined),
      matching: find.byType(InkWell),
    );
    await tester.tap(exerciseDestination);
    await tester.pumpAndSettle();
    final monthlyToggle = find.text('This month');
    await tester.ensureVisible(monthlyToggle);
    await tester.tap(monthlyToggle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exerciseMonthlyDailyChart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Korean locale localises the bottom-nav labels', (tester) async {
    await pumpApp(tester, locale: const Locale('ko'));
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsAtLeastNWidgets(1));
    expect(find.text('식단'), findsAtLeastNWidgets(1));
    expect(find.text('운동'), findsAtLeastNWidgets(1));
    expect(find.text('MY'), findsAtLeastNWidgets(1));
  });

  test('ARB resources expose nav strings for ko + en', () {
    // sanity: 'supportedLocales' is the canonical set.
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('ko')));
  });

  testWidgets('English locale localises the Home AI advice (리뷰 #292)', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));
    // 회귀: 예전엔 '오늘의 AI 통합 조언' 배너가 한국어로 하드코딩돼 영어 로케일에서도
    // 한국어로 노출됐다. 이제 ARB 를 거쳐 영어로 나오고 한국어 리터럴은 없어야 한다.
    expect(find.text("Today's combined AI advice"), findsAtLeastNWidgets(1));
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).homeAiAdviceBody),
      findsOneWidget,
    );
    expect(find.text('오늘의 AI 통합 조언'), findsNothing);
    expect(find.text('나트륨 초과'), findsNothing);
  });

  test(
    'coaching/advice strings are localised — en English, ko Korean (리뷰 #292)',
    () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));
      final RegExp hangul = RegExp('[가-힣]');

      // 코드에 하드코딩돼 있던 문구들이 이제 로케일별 ARB 로 분리됐다.
      expect(en.coachCardDietTitle, 'Great breakfast — watch lunch sodium');
      expect(ko.coachCardDietTitle, '아침 식단 훌륭, 점심 나트륨 주의');
      expect(en.coachCardExerciseTitle, 'Upper-body PT session 12 done');
      expect(en.homeAiAdviceTitle, "Today's combined AI advice");
      expect(ko.homeAiAdviceTitle, '오늘의 AI 통합 조언');
      expect(en.homeSodiumExceededBadge, 'Sodium over');
      expect(ko.homeSodiumExceededBadge, '나트륨 초과');

      // 영어 리소스에 한글이 남아 있지 않아야 한다.
      expect(hangul.hasMatch(en.coachCardDietBody), isFalse);
      expect(hangul.hasMatch(en.coachCardExerciseBody), isFalse);
      expect(hangul.hasMatch(en.homeAiAdviceBody), isFalse);
    },
  );

  test('운동 탭 기간 토글·도넛 라벨이 로케일을 따른다 (#297)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));
    final RegExp hangul = RegExp('[가-힣]');

    // 회귀: '이번 달'만 하드코딩돼 있어 영어 로케일에서 "Today / This week /
    // 이번 달" 처럼 한 토글 안에 두 언어가 섞였다.
    expect(en.exThisMonth, 'This month');
    expect(ko.exThisMonth, '이번 달');
    for (final String s in <String>[
      en.exToday,
      en.exThisWeek,
      en.exThisMonth,
    ]) {
      expect(hangul.hasMatch(s), isFalse);
    }

    // 도넛 세그먼트도 같은 화면에서 한국어로 굳어 있었다.
    expect(en.exTypeCardio, 'Cardio');
    expect(en.exTypeStrength, 'Strength');
    expect(en.exTypeStretching, 'Stretching');
    expect(ko.exTypeCardio, '유산소');
  });

  test('식단·운동 날짜별 빈 상태가 로케일을 따른다 (#297)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));

    expect(ko.otherDateEmpty(ko.pageDietTitle), '선택한 날짜에 기록된 식단이 없어요.');
    expect(ko.otherDateEmpty(ko.pageExerciseTitle), '선택한 날짜에 기록된 운동이 없어요.');
    expect(
      en.otherDateEmpty(en.pageDietTitle),
      'No Diet records for the selected date.',
    );
    expect(
      en.otherDateEmpty(en.pageExerciseTitle),
      'No Exercise records for the selected date.',
    );
    expect(
      RegExp('[가-힣]').hasMatch(en.otherDateEmpty(en.pageDietTitle)),
      isFalse,
    );
  });

  test('운동 탭 UI 골격 문구가 로케일을 따른다 (#367)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));
    final RegExp hangul = RegExp('[가-힣]');

    // 회귀: 운동 현황 카드·도넛·툴팁의 골격 문구가 한국어로 굳어 있어
    // 영어 로케일에서 지표 라벨만 영어로 나왔다.
    expect(en.exTodayTotalTime, "Today's total time");
    expect(ko.exTodayTotalTime, '오늘 총 운동 시간');
    expect(en.exRest, 'Rest');
    expect(ko.exRest, '휴식');
    expect(en.exAiRecommendedExercise, 'AI recommended exercise');
    expect(ko.exAiRecommendedExercise, 'AI 추천 운동');

    // 이번 달 막대 차트의 주차 라벨.
    expect(en.exWeekNumber(3), 'Week 3');
    expect(ko.exWeekNumber(3), '3주');

    for (final String s in <String>[
      en.exTodayTotalTime,
      en.exRest,
      en.exAiRecommendedExercise,
      en.exWeekNumber(1),
      en.unitMinutes,
      en.unitMinutesValue(8),
    ]) {
      expect(hangul.hasMatch(s), isFalse, reason: s);
    }
  });

  test('분 단위는 기존 공용 키를 재사용한다 (#367)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));

    // 신규 키를 만들지 않고 unitMinutes/unitMinutesValue 를 그대로 쓴다.
    expect(ko.unitMinutes, '분');
    expect(en.unitMinutes, 'min');
    expect(ko.unitMinutesValue(8), '8분');
    expect(en.unitMinutesValue(8), '8 min');
  });

  test('운동 탭 하위 위젯 문구가 로케일을 따른다 (#381)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));
    final RegExp hangul = RegExp('[가-힣]');

    // 신규 키 5개 — 나머지 17곳은 기존 키를 재사용했다.
    // '운동 유형' 은 신규 키를 만들지 않고 기존 exExerciseType('운동 종류')으로
    // 합쳤다. exercise_flows 가 같은 개념에 이미 그 키를 쓰고 있어, 두 시트가
    // 서로 다른 말을 하던 것이 정리된다.
    expect(en.exExerciseType, 'Exercise Type');
    expect(ko.exExerciseType, '운동 종류');
    expect(en.exExerciseContent, 'What you did');
    expect(en.exViewDetail, 'View details');
    expect(en.exRegister, 'Register');
    expect(en.actionClose, 'Close');
    expect(en.exGymRegistered('Gangnam Gym'), 'Registered Gangnam Gym');
    expect(ko.exGymRegistered('강남 짐'), '강남 짐을(를) 등록했어요');

    for (final String s in <String>[
      en.exExerciseType,
      en.exExerciseContent,
      en.exViewDetail,
      en.exRegister,
      en.actionClose,
      en.exGymRegistered('Gym'),
      // 재사용한 기존 키도 영문 값이 멀쩡한지 함께 본다.
      en.exStatTime,
      en.exExerciseDuration,
      en.exEnterDuration,
      en.dietDeleteFailed,
      en.dietSaveFailed,
      en.exExerciseLog,
      en.exGymTab,
      en.exTypeOtherChip,
    ]) {
      expect(hangul.hasMatch(s), isFalse, reason: s);
    }
  });
}
