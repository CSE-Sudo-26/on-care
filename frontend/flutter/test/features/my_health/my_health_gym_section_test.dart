import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/my_health/data/repositories/mock_my_health_repository.dart';
import 'package:oncare/features/my_health/presentation/controllers/my_health_controller.dart';
import 'package:oncare/features/my_health/presentation/pages/my_health_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// MY 탭의 "내 트레이너 · 헬스장" 카드는 이동이 아니라 연결 삭제 동작이다.
/// 확인 창을 거쳐야만 삭제되는지, 취소하면 그대로인지 검증한다.
///
/// 저장소를 직접 await 하지 않는 이유: [MockGymRepository] 의 `Future.delayed`
/// 는 위젯 테스트의 가상 시계에서 만료되지 않아 테스트가 멈춘다. 연결 상태는
/// 이미 해소된 [myGymProvider] 를 통해 확인한다.
void main() {
  Future<void> pumpMyTab(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gymRepositoryProvider.overrideWithValue(MockGymRepository()),
          myHealthRepositoryProvider.overrideWithValue(
            const MockMyHealthRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MyHealthPage(),
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

  Future<void> tapGymCard(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      gymCard(),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(gymCard());
    await tester.pumpAndSettle();
  }

  testWidgets('카드를 누르면 삭제 확인 창이 뜬다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapGymCard(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('강남 피트니스 센터 연결을 삭제하시겠습니까?'), findsOneWidget);
  });

  testWidgets('취소하면 연결이 유지된다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapGymCard(tester);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(gymCard(), findsOneWidget);
    expect(await connectedGym(tester), isNotNull);
  });

  testWidgets('삭제하면 카드가 빈 상태로 바뀌고 연결도 해제된다', (WidgetTester tester) async {
    await pumpMyTab(tester);
    await tapGymCard(tester);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(gymCard(), findsNothing);
    expect(find.text('아직 등록된 헬스장이 없어요'), findsOneWidget);
    // 운동 탭도 같은 provider 를 읽으므로 그쪽에서도 연결이 사라진다.
    expect(await connectedGym(tester), isNull);
  });
}
