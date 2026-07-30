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

const Gym _gym = Gym(
  id: 'gym-action-test',
  name: '액션 테스트 헬스장',
  address: '서울시 테스트구',
  distanceKm: 0.5,
  rating: 4.9,
  tags: <String>['PT'],
  trainerName: '김액션',
  trainerRole: '전담 트레이너',
);

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

void main() {
  late GoRouter router;

  Future<void> pumpGymTab(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(AppRoutes.exerciseGym);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myGymProvider.overrideWith((ref) async => _gym),
          nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
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
  }

  Finder myGymCard() => find.byWidgetPredicate(
    (Widget widget) => widget.runtimeType.toString() == '_MyGymTrainerCard',
  );

  Finder reservationPanel() => find.byWidgetPredicate(
    (Widget widget) => widget.runtimeType.toString() == '_ReservationPanel',
  );

  Future<void> scrollToCard(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      myGymCard(),
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('legacy footer actions and their trailing space are removed', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester);
    await scrollToCard(tester);

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(find.text(l.exGymInfo), findsNothing);
    expect(find.text(l.exConsultButton), findsNothing);

    expect(find.text(l.exAiSlotTitle), findsOneWidget);
    expect(
      tester.getBottomRight(myGymCard()).dy -
          tester.getBottomRight(reservationPanel()).dy,
      17,
    );
  });

  testWidgets('gym and trainer information areas keep their detail routes', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester);
    await scrollToCard(tester);

    await tester.tap(
      find.descendant(of: myGymCard(), matching: find.text(_gym.name)),
    );
    await tester.pumpAndSettle();
    expect(find.text('헬스장 상세'), findsOneWidget);

    router.go(AppRoutes.exerciseGym);
    await tester.pumpAndSettle();
    await scrollToCard(tester);
    await tester.tap(
      find.descendant(of: myGymCard(), matching: find.text(_gym.trainerName!)),
    );
    await tester.pumpAndSettle();
    expect(find.text('트레이너 상세'), findsOneWidget);
  });
}
