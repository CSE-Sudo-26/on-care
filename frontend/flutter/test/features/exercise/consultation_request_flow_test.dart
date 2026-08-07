import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const Gym _gym = Gym(
  id: 'gym-consult',
  name: '상담 테스트 헬스장',
  address: '서울시 테스트구',
  distanceKm: 0.7,
  rating: 4.8,
  tags: <String>['근력운동'],
);

const Trainer _trainer = Trainer(
  id: 'trainer-consult',
  gymId: 'gym-consult',
  name: '김상담',
  role: '전담 트레이너',
);

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

ConsultationRequest _request(ConsultationTargetType targetType) {
  return ConsultationRequest(
    id: 'request-${targetType.name}',
    targetType: targetType,
    gymId: _gym.id,
    gymName: _gym.name,
    trainerId: targetType == ConsultationTargetType.trainer
        ? _trainer.id
        : null,
    trainerName: targetType == ConsultationTargetType.trainer
        ? _trainer.name
        : null,
    trainerRole: targetType == ConsultationTargetType.trainer
        ? _trainer.role
        : null,
    exerciseGoal: '체중 감량',
    healthPurpose: '해당 없음',
    preferredDate: DateTime(2026, 7, 28),
    preferredTimeSlot: '오후',
    message: null,
    status: ConsultationStatus.pending,
    createdAt: DateTime(2026, 7, 26),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder target, double delta) {
  final Finder pageScroll = find
      .byWidgetPredicate(
        (Widget widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .last;
  return tester.scrollUntilVisible(target, delta, scrollable: pageScroll);
}

AppLocalizations _localizations(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pumpRoute(
    WidgetTester tester,
    String location, {
    bool hasMyGym = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    container = ProviderContainer(
      overrides: <Override>[
        nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
        myGymProvider.overrideWith((ref) async => hasMyGym ? _gym : null),
        myTrainerProvider.overrideWith(
          (ref) async => hasMyGym ? _trainer : null,
        ),
        trainerProvider(_trainer.id).overrideWith((ref) async => _trainer),
        gymTrainersProvider(
          _gym.id,
        ).overrideWith((ref) async => const <Trainer>[_trainer]),
      ],
    );
    addTearDown(container.dispose);
    router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(location);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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

  test('controller blocks a duplicate target but separates target types', () {
    final ConsultationRequestController controller =
        ConsultationRequestController();

    expect(controller.add(_request(ConsultationTargetType.gym)), isTrue);
    expect(controller.add(_request(ConsultationTargetType.gym)), isFalse);
    expect(controller.add(_request(ConsultationTargetType.trainer)), isTrue);
    expect(controller.state, hasLength(2));
  });

  testWidgets('gym and trainer detail CTAs show different target cards', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      AppRoutes.gymDetailPath(_gym.id),
      hasMyGym: false,
    );
    final AppLocalizations l = _localizations(tester);
    await _scrollTo(tester, find.text(l.exGymConsultRequest), 250);
    await tester.tap(find.text(l.exGymConsultRequest));
    await tester.pumpAndSettle();

    expect(find.text(l.exConsultRequestTitle), findsOneWidget);
    expect(find.text(_gym.name), findsOneWidget);
    expect(find.textContaining(l.exTrainerAssignedLater), findsOneWidget);

    router.go(AppRoutes.trainerDetailPath(_trainer.id));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text(l.exTrainerConsultRequest), 250);
    await tester.tap(find.text(l.exTrainerConsultRequest));
    await tester.pumpAndSettle();

    expect(find.text(_trainer.name), findsOneWidget);
    expect(find.text(_trainer.role!), findsOneWidget);
    expect(find.textContaining(_gym.name), findsOneWidget);
  });

  testWidgets('validation includes required choices and other-purpose input', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      AppRoutes.consultationRequestPath(
        targetType: ConsultationTargetType.gym.name,
        gymId: _gym.id,
      ),
    );
    final AppLocalizations l = _localizations(tester);

    await _scrollTo(tester, find.text(l.exSendConsultRequest), 250);
    await tester.tap(find.text(l.exSendConsultRequest));
    await tester.pump();
    await _scrollTo(tester, find.text(l.exGoalRequired), -250);
    expect(find.text(l.exGoalRequired), findsOneWidget);
    expect(find.text(l.exHealthPurposeRequired), findsOneWidget);

    await tester.tap(find.text(l.exGoalWeightLoss));
    final Finder healthPurposeOther = find.descendant(
      of: find.byKey(const Key('health-purpose-options')),
      matching: find.text(l.exOptionOther),
    );
    await _scrollTo(tester, healthPurposeOther, 200);
    await tester.tap(healthPurposeOther);
    await tester.pump();
    expect(find.text(l.exHealthPurposeInputRequired), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '무릎 통증 관리');
    await tester.pump();
    expect(find.text(l.exHealthPurposeInputRequired), findsNothing);
  });

  testWidgets('valid submission completes, stores pending, and shows status', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      AppRoutes.consultationRequestPath(
        targetType: ConsultationTargetType.gym.name,
        gymId: _gym.id,
      ),
    );
    final AppLocalizations l = _localizations(tester);

    await tester.tap(find.text(l.exGoalWeightLoss));
    await _scrollTo(tester, find.text(l.exPurposeNone), 180);
    await tester.tap(find.text(l.exPurposeNone));
    await _scrollTo(tester, find.text(l.exSelectDate), 180);
    Finder dateMaterial = find
        .ancestor(
          of: find.byIcon(Icons.calendar_today_outlined),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.widget<Material>(dateMaterial).color, FigmaColors.softBlue);
    await tester.tap(find.text(l.exSelectDate));
    await tester.pumpAndSettle();
    final BuildContext pickerContext = tester.element(
      find.byType(DatePickerDialog),
    );
    final DatePickerThemeData pickerTheme = DatePickerTheme.of(pickerContext);
    expect(pickerTheme.backgroundColor, Colors.white);
    expect(pickerTheme.headerBackgroundColor, Colors.white);
    expect(pickerTheme.surfaceTintColor, Colors.transparent);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    dateMaterial = find
        .ancestor(
          of: find.byIcon(Icons.calendar_today_outlined),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.widget<Material>(dateMaterial).color, FigmaColors.softBlue);
    await _scrollTo(tester, find.text(l.exTimeAfternoon), 180);
    await tester.tap(find.text(l.exTimeAfternoon));
    await _scrollTo(tester, find.text(l.exSendConsultRequest), 220);
    await tester.tap(find.text(l.exSendConsultRequest));
    await tester.pumpAndSettle();

    expect(find.text(l.exConsultReceived), findsOneWidget);
    final List<ConsultationRequest> requests = container.read(
      consultationRequestControllerProvider,
    );
    expect(requests, hasLength(1));
    expect(requests.single.status, ConsultationStatus.pending);

    await tester.tap(find.text(l.exReturnExercise));
    await tester.pumpAndSettle();
    expect(find.text(l.exConsultStatusSection), findsOneWidget);
    expect(find.text(l.exConsultPendingStatus), findsOneWidget);

    router.go(AppRoutes.gymDetailPath(_gym.id));
    await tester.pumpAndSettle();
    expect(find.text(l.exConsultPendingCta), findsNothing);
    expect(find.text(l.exGymConsultRequest), findsNothing);
  });

  testWidgets('invalid target type and gym id show a safe state', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      '${AppRoutes.consultationRequest}?targetType=invalid&gymId=missing',
    );
    final AppLocalizations l = _localizations(tester);
    expect(find.text(l.exConsultTargetNotFound), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go(
      AppRoutes.consultationRequestPath(
        targetType: ConsultationTargetType.gym.name,
        gymId: 'missing',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.exConsultTargetNotFound), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
