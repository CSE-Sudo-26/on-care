import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/entities/trainer_slot.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/my_health/data/repositories/mock_my_health_repository.dart';
import 'package:oncare/features/my_health/presentation/controllers/my_health_controller.dart';
import 'package:oncare/features/my_health/presentation/pages/my_health_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class _FailingGymRepository implements GymRepository {
  const _FailingGymRepository();

  @override
  Future<void> disconnectMyGym() async {}

  @override
  Future<void> disconnectMyTrainer() async {}

  @override
  Future<Gym?> fetchMyGym() => Future<Gym?>.error(StateError('boom'));

  @override
  Future<List<Gym>> fetchNearby() async => const <Gym>[];

  @override
  Future<List<TrainerSlot>> fetchSlots(String trainerId) async =>
      const <TrainerSlot>[];

  @override
  Future<void> reserve(String slotId) async {}

  @override
  Future<Trainer?> fetchMyTrainer() async => null;

  @override
  Future<List<Trainer>> fetchTrainersByGym(String gymId) async =>
      const <Trainer>[];

  @override
  Future<List<Trainer>> fetchAllTrainers() async => const <Trainer>[];

  @override
  Future<Trainer?> fetchTrainer(String trainerId) async => null;

  @override
  Future<List<Trainer>> fetchRecommendedTrainers() async => const <Trainer>[];
}

/// MY 탭의 "내 트레이너 · 헬스장" 섹션은 헬스장 연결과 트레이너 연결을 각각
/// 따로 끊을 수 있다. 확인 창을 거쳐야만 삭제되는지, 트레이너만 끊었을 때
/// 헬스장은 남는지 검증한다.
///
/// 저장소를 직접 await 하지 않는 이유: [MockGymRepository] 의 `Future.delayed`
/// 는 위젯 테스트의 가상 시계에서 만료되지 않아 테스트가 멈춘다. 연결 상태는
/// 이미 해소된 provider 를 통해 확인한다.
void main() {
  test('헬스장을 해제하면 트레이너 연결도 함께 사라진다', () async {
    final MockGymRepository repository = MockGymRepository();

    await repository.disconnectMyGym();

    expect(await repository.fetchMyGym(), isNull);
    expect(await repository.fetchMyTrainer(), isNull);
  });

  test('트레이너만 해제해도 헬스장 목록은 그대로다', () async {
    final MockGymRepository repository = MockGymRepository();

    await repository.disconnectMyTrainer();

    expect(await repository.fetchMyGym(), isNotNull);
    expect(await repository.fetchMyTrainer(), isNull);
    // 트레이너는 Gym 에 매달려 있지 않으므로 헬스장 목록은 영향을 받지 않는다.
    expect(await repository.fetchNearby(), isNotEmpty);
  });

  Future<void> pumpMyTab(
    WidgetTester tester, {
    Locale locale = const Locale('ko'),
    GymRepository? gymRepository,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gymRepositoryProvider.overrideWithValue(
            gymRepository ?? MockGymRepository(),
          ),
          myHealthRepositoryProvider.overrideWithValue(
            const MockMyHealthRepository(),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyHealthPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder gymCard() => find.byWidgetPredicate(
    (Widget widget) => widget.runtimeType.toString() == '_GymSummaryCard',
  );

  Future<Gym?> connectedGym(WidgetTester tester) {
    return ProviderScope.containerOf(
      tester.element(find.byType(MyHealthPage)),
    ).read(myGymProvider.future);
  }

  Future<Trainer?> connectedTrainer(WidgetTester tester) {
    return ProviderScope.containerOf(
      tester.element(find.byType(MyHealthPage)),
    ).read(myTrainerProvider.future);
  }

  /// 헬스장 행 / 트레이너 행의 삭제 버튼은 툴팁으로 구분한다.
  Future<void> tapRemove(WidgetTester tester, String tooltip) async {
    await tester.scrollUntilVisible(
      gymCard(),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  testWidgets('연결된 헬스장과 담당 트레이너가 트레이너 앱 시드와 같다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tester.scrollUntilVisible(
      gymCard(),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('온케어짐 신촌점'), findsOneWidget);
    expect(find.text('김트레이너 · 퍼스널 트레이너'), findsOneWidget);
  });

  testWidgets('영어 로케일에서 섹션 액션이 영어로 표시된다', (WidgetTester tester) async {
    await pumpMyTab(tester, locale: const Locale('en'));
    await tester.scrollUntilVisible(
      gymCard(),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('My Trainer & Gym'), findsOneWidget);
    expect(find.byTooltip('Disconnect gym'), findsOneWidget);
    expect(find.byTooltip('Disconnect trainer'), findsOneWidget);
    expect(find.text('내 트레이너 · 헬스장'), findsNothing);
  });

  testWidgets('헬스장 연결 조회 실패 시 재시도 상태를 표시한다', (WidgetTester tester) async {
    await pumpMyTab(tester, gymRepository: const _FailingGymRepository());

    expect(find.text('헬스장 연결 정보를 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('아직 등록된 헬스장이 없어요'), findsNothing);
  });

  testWidgets('헬스장 삭제 버튼은 트레이너도 함께 해제된다고 알린다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapRemove(tester, '헬스장 연결 삭제');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('온케어짐 신촌점 연결을 삭제하시겠습니까?'), findsOneWidget);
    expect(find.textContaining('김트레이너 연결도 함께 해제됩니다'), findsOneWidget);
  });

  testWidgets('취소하면 연결이 유지된다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapRemove(tester, '헬스장 연결 삭제');

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(gymCard(), findsOneWidget);
    expect(await connectedGym(tester), isNotNull);
  });

  testWidgets('헬스장을 삭제하면 카드가 빈 상태로 바뀐다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapRemove(tester, '헬스장 연결 삭제');

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(gymCard(), findsNothing);
    expect(find.text('아직 등록된 헬스장이 없어요'), findsOneWidget);
    // 운동 탭도 같은 provider 를 읽으므로 그쪽에서도 연결이 사라진다.
    expect(await connectedGym(tester), isNull);
    expect(await connectedTrainer(tester), isNull);
  });

  testWidgets('트레이너만 삭제하면 헬스장 연결은 남는다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapRemove(tester, '트레이너 연결 삭제');

    expect(find.textContaining('김트레이너 연결을 삭제하시겠습니까?'), findsOneWidget);
    expect(find.textContaining('헬스장 연결은 유지됩니다'), findsOneWidget);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(gymCard(), findsOneWidget);
    expect(find.text('온케어짐 신촌점'), findsOneWidget);
    expect(find.text('담당 트레이너 없음'), findsOneWidget);
    expect(find.text('트레이너 찾기'), findsOneWidget);

    expect(await connectedGym(tester), isNotNull);
    expect(await connectedTrainer(tester), isNull);
  });

  testWidgets('트레이너를 뗀 뒤에는 트레이너 삭제 버튼이 사라진다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapRemove(tester, '트레이너 연결 삭제');
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('트레이너 연결 삭제'), findsNothing);
    expect(find.byTooltip('헬스장 연결 삭제'), findsOneWidget);
  });
}
