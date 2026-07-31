import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
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

ConsultationRequest _consultation(ConsultationStatus status) {
  return ConsultationRequest(
    id: 'consultation-${status.name}',
    targetType: ConsultationTargetType.trainer,
    gymId: _gym.id,
    gymName: _gym.name,
    trainerName: _gym.trainerName,
    trainerRole: _gym.trainerRole,
    exerciseGoal: '체중 감량',
    healthPurpose: '해당 없음',
    preferredDate: DateTime(2026, 8),
    preferredTimeSlot: '오후',
    message: null,
    status: status,
    createdAt: DateTime(2026, 7, 31),
  );
}

void main() {
  late GoRouter router;
  late ConsultationRequestController consultationController;

  Future<void> pumpGymTab(
    WidgetTester tester, {
    ConsultationRequest? consultation,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    consultationController = ConsultationRequestController();
    if (consultation != null) {
      consultationController.add(consultation);
    }
    router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(AppRoutes.exerciseGym);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myGymProvider.overrideWith((ref) async => _gym),
          nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
          consultationRequestControllerProvider.overrideWith(
            (ref) => consultationController,
          ),
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
    expect(find.text(l.exViewConsultationRequest), findsNothing);

    expect(find.text(l.exAiSlotTitle), findsOneWidget);
    const double expectedBottomInset = 17; // 16px padding + 1px border.
    expect(
      tester.getBottomRight(myGymCard()).dy -
          tester.getBottomRight(reservationPanel()).dy,
      expectedBottomInset,
    );
  });

  testWidgets('pending consultation shows one action and reuses status UI', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(
      tester,
      consultation: _consultation(ConsultationStatus.pending),
    );
    await scrollToCard(tester);

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(find.text(l.exViewConsultationRequest), findsOneWidget);
    expect(find.text(l.exGymInfo), findsNothing);
    expect(find.text(l.exConsultButton), findsNothing);

    final Finder statusSection = find.text(l.exConsultStatusSection);
    final double statusTopBeforeTap = tester.getTopLeft(statusSection).dy;
    final int requestCountBeforeTap = consultationController.state.length;

    await tester.tap(find.text(l.exViewConsultationRequest));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(statusSection).dy, lessThan(statusTopBeforeTap));
    expect(consultationController.state, hasLength(requestCountBeforeTap));
    expect(find.byType(BottomSheet), findsNothing);
  });

  for (final ConsultationStatus status in <ConsultationStatus>[
    ConsultationStatus.accepted,
    ConsultationStatus.rejected,
  ]) {
    testWidgets('${status.name} consultation does not show an action', (
      WidgetTester tester,
    ) async {
      await pumpGymTab(tester, consultation: _consultation(status));
      await scrollToCard(tester);

      final AppLocalizations l = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(find.text(l.exViewConsultationRequest), findsNothing);
    });
  }

  testWidgets('gym and trainer information areas keep their detail routes', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester);
    await scrollToCard(tester);
    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    await tester.tap(
      find.descendant(of: myGymCard(), matching: find.text(_gym.name)),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.exGymDetailTitle), findsOneWidget);

    router.go(AppRoutes.exerciseGym);
    await tester.pumpAndSettle();
    await scrollToCard(tester);
    await tester.tap(
      find.descendant(of: myGymCard(), matching: find.text(_gym.trainerName!)),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.exTrainerDetailTitle), findsOneWidget);
  });
}
