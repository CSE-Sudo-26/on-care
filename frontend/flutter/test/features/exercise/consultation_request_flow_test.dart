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
  id: 'gym-consult',
  name: '상담 테스트 헬스장',
  address: '서울시 테스트구',
  distanceKm: 0.7,
  rating: 4.8,
  tags: <String>['근력운동'],
  trainerName: '김상담',
  trainerRole: '전담 트레이너',
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
    trainerName: targetType == ConsultationTargetType.trainer
        ? _gym.trainerName
        : null,
    trainerRole: targetType == ConsultationTargetType.trainer
        ? _gym.trainerRole
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

void main() {
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pumpRoute(WidgetTester tester, String location) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    container = ProviderContainer(
      overrides: <Override>[
        nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
        myGymProvider.overrideWith((ref) async => _gym),
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
    await pumpRoute(tester, AppRoutes.gymDetailPath(_gym.id));
    await _scrollTo(tester, find.text('헬스장 상담 요청하기'), 250);
    await tester.tap(find.text('헬스장 상담 요청하기'));
    await tester.pumpAndSettle();

    expect(find.text('상담 요청'), findsOneWidget);
    expect(find.text(_gym.name), findsOneWidget);
    expect(find.textContaining('헬스장에서 확인 후 배정돼요'), findsOneWidget);

    router.go(AppRoutes.trainerDetailPath(_gym.id));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('트레이너 상담 요청하기'), 250);
    await tester.tap(find.text('트레이너 상담 요청하기'));
    await tester.pumpAndSettle();

    expect(find.text(_gym.trainerName!), findsOneWidget);
    expect(find.text(_gym.trainerRole!), findsOneWidget);
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

    await _scrollTo(tester, find.text('상담 요청 보내기'), 250);
    await tester.tap(find.text('상담 요청 보내기'));
    await tester.pump();
    await _scrollTo(tester, find.text('운동 목표를 선택해주세요.'), -250);
    expect(find.text('운동 목표를 선택해주세요.'), findsOneWidget);
    expect(find.text('건강관리 목적을 선택해주세요.'), findsOneWidget);

    await tester.tap(find.text('체중 감량'));
    await _scrollTo(tester, find.text('기타').last, 200);
    await tester.tap(find.text('기타').last);
    await tester.pump();
    expect(find.text('건강관리 목적을 입력해주세요.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '무릎 통증 관리');
    await tester.pump();
    expect(find.text('건강관리 목적을 입력해주세요.'), findsNothing);
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

    await tester.tap(find.text('체중 감량'));
    await _scrollTo(tester, find.text('해당 없음'), 180);
    await tester.tap(find.text('해당 없음'));
    await _scrollTo(tester, find.text('날짜를 선택해주세요'), 180);
    await tester.tap(find.text('날짜를 선택해주세요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('오후'), 180);
    await tester.tap(find.text('오후'));
    await _scrollTo(tester, find.text('상담 요청 보내기'), 220);
    await tester.tap(find.text('상담 요청 보내기'));
    await tester.pumpAndSettle();

    expect(find.text('상담 요청이 접수되었어요'), findsOneWidget);
    final List<ConsultationRequest> requests = container.read(
      consultationRequestControllerProvider,
    );
    expect(requests, hasLength(1));
    expect(requests.single.status, ConsultationStatus.pending);

    await tester.tap(find.text('운동 탭으로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('상담 요청 현황'), findsOneWidget);
    expect(find.text('요청 대기'), findsOneWidget);

    router.go(AppRoutes.gymDetailPath(_gym.id));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('상담 요청 대기 중'), 250);
    final FilledButton pendingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '상담 요청 대기 중'),
    );
    expect(pendingButton.onPressed, isNull);
  });

  testWidgets('invalid target type and gym id show a safe state', (
    WidgetTester tester,
  ) async {
    await pumpRoute(
      tester,
      '${AppRoutes.consultationRequest}?targetType=invalid&gymId=missing',
    );
    expect(find.text('상담 대상 정보를 찾을 수 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go(
      AppRoutes.consultationRequestPath(
        targetType: ConsultationTargetType.gym.name,
        gymId: 'missing',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('상담 대상 정보를 찾을 수 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
