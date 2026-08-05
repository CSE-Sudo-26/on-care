import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/app/app.dart';
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
            const MockDashboardRepository() as DashboardRepository,
          ),
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

  testWidgets('Enters the Home tab in English after demo', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    // Bottom-nav labels match the React original.
    expect(find.text('Home'), findsAtLeastNWidgets(1));
    expect(find.text('Diet'), findsAtLeastNWidgets(1));
    expect(find.text('Exercise'), findsAtLeastNWidgets(1));
    expect(find.text('MY'), findsAtLeastNWidgets(1));
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

    await tester.tap(find.text('Exercise').first);
    await tester.pumpAndSettle();
    expect(find.text('Exercise'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('MY').first);
    await tester.pumpAndSettle();
    expect(find.text('MY'), findsAtLeastNWidgets(1));
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
    expect(find.text('오늘의 AI 통합 조언'), findsNothing);
    expect(find.text('나트륨 초과'), findsNothing);
  });

  test('coaching/advice strings are localised — en English, ko Korean (리뷰 #292)', () {
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
  });

  test('운동 탭 기간 토글·도넛 라벨이 로케일을 따른다 (#297)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));
    final RegExp hangul = RegExp('[가-힣]');

    // 회귀: '이번 달'만 하드코딩돼 있어 영어 로케일에서 "Today / This week /
    // 이번 달" 처럼 한 토글 안에 두 언어가 섞였다.
    expect(en.exThisMonth, 'This month');
    expect(ko.exThisMonth, '이번 달');
    for (final String s in <String>[en.exToday, en.exThisWeek, en.exThisMonth]) {
      expect(hangul.hasMatch(s), isFalse);
    }

    // 도넛 세그먼트도 같은 화면에서 한국어로 굳어 있었다.
    expect(en.exTypeCardio, 'Cardio');
    expect(en.exTypeStrength, 'Strength');
    expect(en.exTypeStretching, 'Stretching');
    expect(ko.exTypeCardio, '유산소');
  });

  test('식단·운동 빈 상태가 한 문구를 공유한다 (#297)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));

    // 두 탭이 같은 키를 쓰고 섹션 이름만 갈아끼운다 — 문구가 갈라지지 않게.
    expect(ko.otherDateEmpty(ko.pageDietTitle), contains('식단을 확인해'));
    expect(ko.otherDateEmpty(ko.pageExerciseTitle), contains('운동을 확인해'));
    expect(en.otherDateEmpty(en.pageDietTitle), contains('your Diet records'));
    expect(
      en.otherDateEmpty(en.pageExerciseTitle),
      contains('your Exercise records'),
    );
    // 앞 문장은 두 탭이 완전히 동일해야 한다(중복 문구 재분기 방지).
    expect(
      ko.otherDateEmpty(ko.pageDietTitle).split('\n').first,
      ko.otherDateEmpty(ko.pageExerciseTitle).split('\n').first,
    );
    expect(RegExp('[가-힣]').hasMatch(en.otherDateEmpty(en.pageDietTitle)), isFalse);
  });
}
