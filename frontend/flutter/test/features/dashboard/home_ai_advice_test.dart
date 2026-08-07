import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:oncare/app/app.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/core/logging/app_logger.dart';
import 'package:oncare/core/storage/app_database.dart';
import 'package:oncare/core/storage/seed_data.dart';
import 'package:oncare/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/exercise/data/repositories/mock_exercise_repository.dart';
import 'package:oncare/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/services/locale_provider.dart';

/// 홈 '오늘의 AI 통합 조언'은 소스가 둘(데모 mock, 시드 KV)이라 한쪽만 고치면
/// 조용히 갈라진다. 실제로 `dashboardRepositoryProvider` 가 데모에서 mock 을
/// 보게 바뀌자, 시드가 준비한 통합 조언 대신 mock 의 나트륨 단문이 노출됐다.
void main() {
  test('데모 mock 요약이 통합 조언을 그대로 싣는다', () async {
    final DashboardSummary summary = await MockDashboardRepository(MockDietRepository())
        .fetchSummary();

    // 홈은 sodiumWarning 을 통합 조언 자리로 쓴다(dashboard_content.dart).
    expect(summary.sodiumWarning, kDemoAiAdvice);
    expect(summary.sodiumWarning, contains('짬뽕'));
  });

  test('시드 KV 도 같은 문구를 쓴다 — 두 경로가 갈라지지 않는다', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await seedIfEmpty(db);

    expect(await db.readValue('dashboard_ai_advice'), kDemoAiAdvice);
  });

  test('ARB 폴백도 같은 문구다', () {
    final AppLocalizations ko = lookupAppLocalizations(const Locale('ko'));

    expect(ko.homeAiAdviceBody, kDemoAiAdvice);
  });

  // 위 세 건은 소스가 일치하는지만 본다. 실제로 홈 카드에 올라오는지는 앱을
  // 데모로 띄워 확인한다 — 소스가 맞아도 `dashboardRepositoryProvider` 분기가
  // 또 바뀌면 화면에는 다른 값이 나올 수 있다.
  testWidgets('데모 홈 화면이 통합 조언을 렌더한다', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const AppConfig config = AppConfig(
      environment: Environment.dev,
      apiBaseUrl: 'https://dev.api.test',
      useMockApi: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(config),
          appLoggerProvider.overrideWithValue(Logger(level: Level.off)),
          dietRepositoryProvider.overrideWithValue(
            MockDietRepository() as DietRepository,
          ),
          exerciseRepositoryProvider.overrideWithValue(
            MockExerciseRepository() as ExerciseRepository,
          ),
          // dashboardRepositoryProvider 는 일부러 덮지 않는다 — 데모에서 어떤
          // 저장소가 뽑히는지가 이 테스트의 핵심이다.
          localeProvider.overrideWith((ref) => const Locale('ko')),
        ],
        child: const OncareApp(),
      ),
    );
    await tester.pumpAndSettle();

    final Finder demoButton = find.byKey(const Key('demoEnterButton'));
    await tester.ensureVisible(demoButton);
    await tester.pumpAndSettle();
    await tester.tap(demoButton);
    await tester.pumpAndSettle();

    expect(find.text('오늘의 AI 통합 조언'), findsOneWidget);
    expect(find.text(kDemoAiAdvice), findsOneWidget);
  });
}
