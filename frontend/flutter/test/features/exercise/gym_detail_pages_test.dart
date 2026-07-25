import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const Gym _gymWithTrainer = Gym(
  id: 'gym-test',
  name: '테스트 헬스장',
  address: '서울시 테스트구',
  distanceKm: 0.7,
  rating: 4.8,
  tags: <String>['근력운동'],
  trainerName: '김테스트',
  trainerRole: '전담 트레이너',
  weekdayHours: '06:00 - 23:00',
  weekendHours: '08:00 - 20:00',
  phone: '02-0000-0000',
);

const Gym _gymWithoutTrainer = Gym(
  id: 'gym-no-trainer',
  name: '트레이너 없는 헬스장',
  address: '서울시 테스트구',
  distanceKm: 1.2,
  rating: 4.2,
  tags: <String>[],
);

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

void main() {
  Future<GoRouter> pumpRoute(
    WidgetTester tester, {
    required String location,
    List<Gym> gyms = const <Gym>[_gymWithTrainer, _gymWithoutTrainer],
    Gym? myGym,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(location);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          nearbyGymsProvider.overrideWith((ref) async => gyms),
          myGymProvider.overrideWith((ref) async => myGym),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('gym and trainer list rows open their detail routes', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpRoute(tester, location: AppRoutes.gyms);

    await tester.tap(find.text(_gymWithTrainer.name));
    await tester.pumpAndSettle();
    expect(find.text('헬스장 상세'), findsOneWidget);

    router.go(AppRoutes.trainers);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_gymWithTrainer.trainerName!));
    await tester.pumpAndSettle();
    expect(find.text('트레이너 상세'), findsOneWidget);
  });

  testWidgets('detail pages link between the gym and its trainer', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      location: AppRoutes.gymDetailPath(_gymWithTrainer.id),
    );

    await tester.scrollUntilVisible(
      find.text(_gymWithTrainer.trainerName!),
      250,
    );
    await tester.tap(find.text(_gymWithTrainer.trainerName!));
    await tester.pumpAndSettle();
    expect(find.text('트레이너 상세'), findsOneWidget);

    await tester.scrollUntilVisible(find.text(_gymWithTrainer.name), 250);
    await tester.tap(find.text(_gymWithTrainer.name));
    await tester.pumpAndSettle();
    expect(find.text('헬스장 상세'), findsOneWidget);
  });

  testWidgets('missing gym or trainer data shows a safe empty state', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpRoute(
      tester,
      location: AppRoutes.gymDetailPath('missing'),
      gyms: const <Gym>[_gymWithoutTrainer],
    );
    expect(find.text('헬스장 정보를 찾을 수 없어요.'), findsOneWidget);

    router.go(AppRoutes.trainerDetailPath(_gymWithoutTrainer.id));
    await tester.pumpAndSettle();
    expect(find.text('트레이너 정보를 찾을 수 없어요.'), findsOneWidget);
  });
}
