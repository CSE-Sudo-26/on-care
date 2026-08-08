import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../support/consultation_test_support.dart';

const Gym _gym = Gym(
  id: 'gym-action-test',
  name: '액션 테스트 헬스장',
  address: '서울시 테스트구',
  distanceKm: 0.5,
  rating: 4.9,
  tags: <String>['PT'],
);

const Trainer _trainer = Trainer(
  id: 'trainer-action-test',
  gymId: 'gym-action-test',
  name: '김액션',
  role: '전담 트레이너',
);

const MemberCoach _coach = MemberCoach(
  trainerId: 'trainer-action-test',
  name: '김액션',
  specialty: '전담 트레이너',
  career: '5년',
  intro: '건강한 운동을 돕습니다.',
  gymName: '액션 테스트 헬스장',
  goal: '체력 강화',
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
    trainerId: _trainer.id,
    trainerName: _trainer.name,
    trainerRole: _trainer.role,
    exerciseGoal: ExerciseGoal.weightLoss,
    healthPurposeType: HealthPurposeType.chronic,
    healthPurposeDetail: null,
    preferredDate: DateTime(2026, 8),
    preferredTimeSlot: PreferredTimeSlot.afternoon,
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
    List<ConsultationRequest> additionalConsultations =
        const <ConsultationRequest>[],
    bool hasMyGym = true,
    Trainer? trainer = _trainer,
    MemberCoach? coach,
    int unread = 0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    consultationController = newTestConsultationController();
    if (consultation != null) {
      await seedPending(consultationController, consultation);
    }
    for (final ConsultationRequest request in additionalConsultations) {
      await seedPending(consultationController, request);
    }
    router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(AppRoutes.exerciseGym);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myGymProvider.overrideWith((ref) async => hasMyGym ? _gym : null),
          nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
          // 헬스장 상세·찾기는 제휴 + 카카오를 합친 provider 를 본다(#329).
          gymFinderResultsProvider.overrideWith(
            (ref) async => const <Gym>[_gym],
          ),
          myTrainerProvider.overrideWith((ref) async => trainer),
          trainerProvider(_trainer.id).overrideWith((ref) async => _trainer),
          gymTrainersProvider(
            _gym.id,
          ).overrideWith((ref) async => const <Trainer>[_trainer]),
          recommendedTrainersProvider.overrideWith(
            (ref) async => const <Trainer>[_trainer],
          ),
          consultationRequestControllerProvider.overrideWith(
            (ref) => consultationController,
          ),
          memberCoachRepositoryProvider.overrideWithValue(
            MockMemberCoachRepository(),
          ),
          memberCoachProvider.overrideWith((ref) async => coach),
          coachUnreadProvider.overrideWith((ref) async => unread),
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
    (Widget widget) => widget.runtimeType.toString() == '_MyGymCard',
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
    expect(find.text(l.exMyGymSection), findsOneWidget);
    expect(
      find.descendant(of: myGymCard(), matching: find.text(_trainer.name)),
      findsNothing,
    );

    expect(find.text(l.exAiSlotTitle), findsOneWidget);
    const double expectedBottomInset = 17; // 16px padding + 1px border.
    expect(
      tester.getBottomRight(myGymCard()).dy -
          tester.getBottomRight(reservationPanel()).dy,
      expectedBottomInset,
    );
  });

  testWidgets('gym finder removes only the unused trainer chat action', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester, hasMyGym: false);
    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    await tester.tap(find.text(l.exFindGym));
    await tester.pumpAndSettle();

    expect(find.text('트레이너 채팅'), findsNothing);
    expect(find.text(l.exSendHealthSummary), findsWidgets);
  });

  testWidgets('pending consultation shows one action and reuses status UI', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(
      tester,
      consultation: _consultation(ConsultationStatus.pending),
      coach: _coach,
    );
    await scrollToCard(tester);

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(find.text(l.exViewConsultationRequest), findsOneWidget);
    expect(find.text(l.exGymInfo), findsNothing);
    expect(find.text(l.exConsultButton), findsNothing);
    expect(find.byKey(const Key('gymTrainerChatButton')), findsNothing);

    final Finder statusSection = find.text(l.exConsultStatusSection);
    final double statusTopBeforeTap = tester.getTopLeft(statusSection).dy;
    final int requestCountBeforeTap = consultationController.state.length;

    await tester.tap(find.text(l.exViewConsultationRequest));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(statusSection).dy, lessThan(statusTopBeforeTap));
    expect(consultationController.state, hasLength(requestCountBeforeTap));
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('connected trainer shows chat without a zero badge', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester, coach: _coach);
    await scrollToCard(tester);

    final Finder chatButton = find.byKey(const Key('gymTrainerChatButton'));
    expect(chatButton, findsOneWidget);
    expect(
      find.descendant(of: chatButton, matching: find.text('0')),
      findsNothing,
    );

    await tester.tap(chatButton);
    await tester.pumpAndSettle();

    expect(find.byType(TrainerChatPage), findsOneWidget);
    expect(find.text(_coach.name), findsOneWidget);
  });

  testWidgets('connected trainer can open chat without a member gym link', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester, hasMyGym: false, coach: _coach);

    expect(find.byKey(const Key('gymTrainerChatButton')), findsOneWidget);
  });

  testWidgets(
    'pending consultation keeps its action without a member gym link',
    (WidgetTester tester) async {
      await pumpGymTab(
        tester,
        hasMyGym: false,
        consultation: _consultation(ConsultationStatus.pending),
        coach: _coach,
      );

      final AppLocalizations l = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(find.text(l.exViewConsultationRequest), findsOneWidget);
      expect(find.byKey(const Key('gymTrainerChatButton')), findsNothing);
    },
  );

  testWidgets('any pending consultation keeps the consultation action', (
    WidgetTester tester,
  ) async {
    final ConsultationRequest recentAcceptedRequest = ConsultationRequest(
      id: 'consultation-recent-accepted',
      targetType: ConsultationTargetType.trainer,
      gymId: _gym.id,
      gymName: _gym.name,
      trainerId: 'another-trainer',
      trainerName: '박최근',
      trainerRole: '전담 트레이너',
      exerciseGoal: ExerciseGoal.weightLoss,
      healthPurposeType: HealthPurposeType.chronic,
      healthPurposeDetail: null,
      preferredDate: DateTime(2026, 8),
      preferredTimeSlot: PreferredTimeSlot.afternoon,
      message: null,
      status: ConsultationStatus.accepted,
      createdAt: DateTime(2026, 8),
    );
    await pumpGymTab(
      tester,
      consultation: _consultation(ConsultationStatus.pending),
      additionalConsultations: <ConsultationRequest>[recentAcceptedRequest],
      coach: _coach,
    );
    await scrollToCard(tester);

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(find.text(l.exViewConsultationRequest), findsOneWidget);
    expect(find.byKey(const Key('gymTrainerChatButton')), findsNothing);
    expect(find.text(l.exConsultPendingStatus), findsOneWidget);
    expect(find.text('박최근'), findsNothing);
  });

  testWidgets('connected trainer shows unread count and caps it at 99+', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester, coach: _coach, unread: 100);
    await scrollToCard(tester);

    final Finder chatButton = find.byKey(const Key('gymTrainerChatButton'));
    expect(
      find.descendant(of: chatButton, matching: find.text('99+')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chatButton, matching: find.text('100')),
      findsNothing,
    );
  });

  testWidgets('connected trainer shows the actual unread count below 100', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester, coach: _coach, unread: 7);
    await scrollToCard(tester);

    final Finder chatButton = find.byKey(const Key('gymTrainerChatButton'));
    expect(
      find.descendant(of: chatButton, matching: find.text('7')),
      findsOneWidget,
    );
  });

  testWidgets('member without an active trainer has no chat action', (
    WidgetTester tester,
  ) async {
    await pumpGymTab(tester);
    await scrollToCard(tester);

    expect(find.byKey(const Key('gymTrainerChatButton')), findsNothing);
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

  testWidgets('my gym information keeps its detail route', (
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
  });

  testWidgets('담당 트레이너가 없으면 예약 패널을 감춘다', (WidgetTester tester) async {
    await pumpGymTab(tester, trainer: null);
    await scrollToCard(tester);

    final AppLocalizations l = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    // 헬스장 카드는 남지만, 없는 트레이너의 빈 시간·예약 버튼은 사라진다.
    expect(myGymCard(), findsOneWidget);
    expect(reservationPanel(), findsNothing);
    expect(find.text(l.exAiSlotTitle), findsNothing);
    // 내 카드에서만 빠질 뿐, 추천 트레이너 레일에는 그대로 남아 있어야 한다.
    expect(
      find.descendant(of: myGymCard(), matching: find.text(_trainer.name)),
      findsNothing,
    );
    expect(find.text(_trainer.name), findsWidgets);
  });
}
