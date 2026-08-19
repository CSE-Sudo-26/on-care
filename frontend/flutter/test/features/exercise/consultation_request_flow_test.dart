import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../support/consultation_test_support.dart';

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

ConsultationRequest _request({String trainerId = 'trainer-consult'}) {
  return ConsultationRequest(
    id: 'request-$trainerId',
    trainerId: trainerId,
    trainerName: _trainer.name,
    trainerRole: _trainer.role,
    exerciseGoal: ExerciseGoal.weightLoss,
    healthPurposeType: HealthPurposeType.chronic,
    healthPurposeDetail: null,
    preferredDate: DateTime(2026, 7, 28),
    preferredTimeSlot: PreferredTimeSlot.afternoon,
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

/// 상담 요청 폼 안에서 대상을 화면(뷰포트) 안까지 스크롤해 실제로 탭 가능한
/// 상태로 만든다.
///
/// `_scrollTo` 가 잡는 "마지막 `Scrollable`" 은 이 화면에 있는 `문의 내용`
/// `TextField` 가 내부적으로 쓰는 편집 스크롤(`restorationId: "editable"`,
/// 스크롤 범위 항상 0)을 집어버려 아무 것도 스크롤하지 못한다 — 상담 폼은
/// `consult-form` 키로 직접 잡아야 한다는 것을 그 위젯 코멘트(#640)가 이미
/// 말하고 있다. `.first` 로 폼 자신의 `Scrollable` 을 고른다(`.last` 를 쓰면
/// 트리 순회가 더 깊이 들어간 `TextField` 내부 스크롤을 집는다).
///
/// 두 단계로 나뉜다: `scrollUntilVisible` 은 대상이 위젯 트리에 **지어지는**
/// 순간(= cacheExtent 안)에 멈추므로, 화면 안까지 마저 스크롤하는
/// `Scrollable.ensureVisible` 을 이어서 부른다. 정렬은 가운데(0.5)로 둔다 —
/// 기본 정렬(0.0, 위쪽 끝맞춤)은 대상을 AppBar 바로 아래 경계에 딱 붙여,
/// 반올림 오차로 몇 픽셀만 가려져도 탭이 빗나간다. 마지막 `pump` 가 없으면
/// `ensureVisible` 의 스크롤이 다음 프레임에야 반영되어 같은 문제가 난다.
///
/// 상단 데이터 공유 안내(#935)로 폼이 길어지기 전까지는 대부분의 항목이 초기
/// 뷰포트+cacheExtent 안에 있어 이 구분이 드러나지 않았을 뿐이다.
Future<void> _revealInForm(
  WidgetTester tester,
  Finder target,
  double delta,
) async {
  final Finder formScrollable = find
      .descendant(
        of: find.byKey(const Key('consult-form')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(target, delta, scrollable: formScrollable);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump();
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
        // gymRepository·consultationRepository 가 이 값으로 mock/실 API 를 고른다.
        appConfigProvider.overrideWithValue(_config),
        nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
        // 헬스장 상세·찾기는 제휴 + 카카오를 합친 provider 를 본다(#329).
        gymFinderResultsProvider.overrideWith((ref) async => const <Gym>[_gym]),
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

  test(
    'controller blocks a duplicate trainer but not a different one',
    () async {
      final ConsultationRequestController controller =
          newTestConsultationController();

      expect(await seedPending(controller, _request()), isTrue);
      expect(await seedPending(controller, _request()), isFalse);
      // 답이 없는 트레이너 한 명이 회원을 묶어 두면 안 된다.
      expect(
        await seedPending(controller, _request(trainerId: 'trainer-other')),
        isTrue,
      );
      expect(controller.state, hasLength(2));
    },
  );

  testWidgets('gym CTA picks a trainer before opening the form', (
    WidgetTester tester,
  ) async {
    await pumpRoute(tester, AppRoutes.gymDetailPath(_gym.id), hasMyGym: false);
    final AppLocalizations l = _localizations(tester);
    await _scrollTo(tester, find.text(l.exGymConsultRequest), 250);
    await tester.tap(find.text(l.exGymConsultRequest));
    await tester.pumpAndSettle();

    // 헬스장에서 시작해도 요청은 트레이너 한 사람 앞으로 간다 — 고르기 전에는
    // 폼으로 넘어가지 않는다.
    expect(find.text(l.exGymConsultPickTrainer), findsOneWidget);
    expect(find.text(l.exConsultRequestTitle), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('gym-consult-trainer-picker')),
        matching: find.text(_trainer.name),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.exConsultRequestTitle), findsOneWidget);
    expect(find.text(_trainer.name), findsOneWidget);
    expect(find.textContaining(_gym.name), findsOneWidget);
  });

  testWidgets('trainer detail CTA opens the form for that trainer', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      AppRoutes.trainerDetailPath(_trainer.id),
      hasMyGym: false,
    );
    final AppLocalizations l = _localizations(tester);
    await _scrollTo(tester, find.text(l.exTrainerConsultRequest), 250);
    await tester.tap(find.text(l.exTrainerConsultRequest));
    await tester.pumpAndSettle();

    expect(find.text(_trainer.name), findsOneWidget);
    expect(find.text(_trainer.role!), findsOneWidget);
    expect(find.textContaining(_gym.name), findsOneWidget);
  });

  testWidgets(
    'shows what gets shared with the trainer once the request is accepted (#935)',
    (WidgetTester tester) async {
      await pumpRoute(
        tester,
        AppRoutes.consultationRequestPath(
          gymId: _gym.id,
          trainerId: _trainer.id,
        ),
      );
      final AppLocalizations l = _localizations(tester);

      expect(
        find.byKey(const Key('consult-data-sharing-notice')),
        findsOneWidget,
      );
      expect(find.text(l.exConsultDataSharingNotice), findsOneWidget);
    },
  );

  testWidgets('validation includes required choices and other-purpose input', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      AppRoutes.consultationRequestPath(gymId: _gym.id, trainerId: _trainer.id),
    );
    final AppLocalizations l = _localizations(tester);

    await _revealInForm(tester, find.text(l.exSendConsultRequest), 250);
    await tester.tap(find.text(l.exSendConsultRequest));
    await tester.pump();
    // 맨 아래에서 제출한 뒤라 상단의 에러 문구가 캐시 범위 밖으로 빠져 있다 —
    // 다시 위로 스크롤해야 트리에 지어진다.
    await _revealInForm(tester, find.text(l.exGoalRequired), -250);
    expect(find.text(l.exGoalRequired), findsOneWidget);
    expect(find.text(l.exHealthPurposeRequired), findsOneWidget);

    await tester.tap(find.text(l.exGoalWeightLoss));
    final Finder healthPurposeOther = find.descendant(
      of: find.byKey(const Key('health-purpose-options')),
      matching: find.text(l.exOptionOther),
    );
    await _revealInForm(tester, healthPurposeOther, 200);
    await tester.tap(healthPurposeOther);
    await tester.pump();
    // "기타" 선택으로 그 아래 입력란·에러 문구가 새로 생겨 레이아웃이
    // 밀린다 — 칩까지만 보이던 스크롤 위치에서는 아직 캐시 범위 밖일 수 있다.
    await _revealInForm(tester, find.text(l.exHealthPurposeInputRequired), 150);
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
      AppRoutes.consultationRequestPath(gymId: _gym.id, trainerId: _trainer.id),
    );
    final AppLocalizations l = _localizations(tester);

    await tester.tap(find.text(l.exGoalWeightLoss));
    await _revealInForm(tester, find.text(l.exPurposeNone), 180);
    await tester.tap(find.text(l.exPurposeNone));
    await _revealInForm(tester, find.text(l.exSelectDate), 180);
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
    await _revealInForm(tester, find.text(l.exTimeAfternoon), 180);
    await tester.tap(find.text(l.exTimeAfternoon));
    await _revealInForm(tester, find.text(l.exSendConsultRequest), 220);
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
        gymId: 'missing',
        trainerId: _trainer.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.exConsultTargetNotFound), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
