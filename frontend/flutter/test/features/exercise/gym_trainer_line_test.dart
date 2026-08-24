/// 헬스장 카드의 트레이너 줄과 지도·목록 접기 (#1185 · #1186 · #1187).
///
///  * 찾기 목록의 헬스장 카드는 그곳 소속 트레이너를 전원 적는다 — 헬스장을
///    견주는 자리에서 누가 있는지가 카드 안에서 읽혀야 한다.
///  * 연결된 내 헬스장 카드는 담당 트레이너를 `연결됨` 배지와 상세보기와 함께
///    한 줄로 적는다.
///  * 지도 위의 결과 시트는 세 자리(목록만·반반·지도만)를 오가고, 머리줄
///    화살표는 그 시트와 같은 자리를 가리킨다 (#1274).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/app_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/pages/trainer_detail_page.dart';
import 'package:oncare/features/exercise/presentation/widgets/kakao_map/kakao_map_view.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const Gym _gym = Gym(
  id: 'gym-trainer-line',
  name: '트레이너 줄 헬스장',
  address: '서울시 테스트구',
  distanceKm: 0.4,
  rating: 4.8,
  tags: <String>['다이어트', '재활운동'],
);

const Trainer _kim = Trainer(
  id: 'trainer-kim',
  gymId: 'gym-trainer-line',
  name: '김트레이너',
  role: '퍼스널 트레이너',
  reason: '혈압 관리와 운동 병행 지도',
);

const Trainer _park = Trainer(
  id: 'trainer-park',
  gymId: 'gym-trainer-line',
  name: '박트레이너',
  role: '재활 트레이너',
  reason: '무릎·허리 통증 관리 다수 경험',
);

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost',
  useMockApi: true,
);

void main() {
  late GoRouter router;

  Future<void> pumpGymTab(
    WidgetTester tester, {
    bool hasMyGym = true,
    Trainer? myTrainer = _kim,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    router = buildAppRouter(config: _config);
    addTearDown(router.dispose);
    router.go(AppRoutes.exerciseGym);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_config),
          myGymProvider.overrideWith((ref) async => hasMyGym ? _gym : null),
          nearbyGymsProvider.overrideWith((ref) async => const <Gym>[_gym]),
          gymFinderResultsProvider.overrideWith(
            (ref) async => const <Gym>[_gym],
          ),
          myTrainerProvider.overrideWith((ref) async => myTrainer),
          trainerProvider(_kim.id).overrideWith((ref) async => _kim),
          gymTrainersProvider(
            _gym.id,
          ).overrideWith((ref) async => const <Trainer>[_kim, _park]),
          recommendedTrainersProvider.overrideWith(
            (ref) async => const <Trainer>[],
          ),
          memberCoachRepositoryProvider.overrideWithValue(
            MockMemberCoachRepository(),
          ),
          memberCoachProvider.overrideWith((ref) async => null),
          myReservationsProvider.overrideWith((ref) async => const []),
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

  group('내 헬스장 카드의 담당 트레이너 줄 (#1187)', () {
    testWidgets('이름·직함과 함께 연결됨·상세보기가 붙는다', (WidgetTester tester) async {
      await pumpGymTab(tester);

      expect(find.byKey(const Key('gym-trainer-line-mine')), findsOneWidget);
      expect(find.text('김트레이너'), findsWidgets);
      expect(find.text('퍼스널 트레이너'), findsWidgets);
      // 카드 머리와 트레이너 줄, 두 곳이 `연결됨` 을 말한다.
      expect(find.text('연결됨'), findsNWidgets(2));
      expect(find.text('상세보기'), findsOneWidget);
      // 이미 함께 하는 사람에게 고를 이유를 다시 적지 않는다.
      expect(find.textContaining('추천 이유'), findsNothing);
    });

    testWidgets('연결됨은 이름 옆에, 상세보기는 줄 오른쪽 끝에 선다 (#1267)', (
      WidgetTester tester,
    ) async {
      await pumpGymTab(tester);

      final Finder line = find.byKey(const Key('gym-trainer-line-mine'));
      final Finder name = find.descendant(
        of: line,
        matching: find.text('김트레이너'),
      );
      final Finder badge = find.descendant(
        of: line,
        matching: find.byKey(const Key('gymTrainerConnectedBadge')),
      );
      final Finder detail = find.descendant(
        of: line,
        matching: find.byKey(const Key('gymTrainerDetailButton')),
      );

      // 배지는 이름에 붙어 있다 — 남는 폭만큼 떨어져 허공에 뜨지 않는다.
      final double gap =
          tester.getTopLeft(badge).dx - tester.getTopRight(name).dx;
      expect(gap, lessThan(24));

      // 상세보기는 줄 오른쪽 끝. 배지보다 오른쪽이고, 줄 끝과 거의 붙는다.
      expect(
        tester.getTopLeft(detail).dx,
        greaterThan(tester.getTopRight(badge).dx),
      );
      expect(
        tester.getBottomRight(line).dx - tester.getBottomRight(detail).dx,
        lessThan(16),
      );
    });

    testWidgets('상세보기를 누르면 트레이너 상세로 간다', (WidgetTester tester) async {
      await pumpGymTab(tester);

      await tester.tap(find.text('상세보기'));
      await tester.pumpAndSettle();

      expect(find.byType(TrainerDetailPage), findsOneWidget);
    });

    testWidgets('담당 트레이너가 없으면 줄 자체가 없다', (WidgetTester tester) async {
      await pumpGymTab(tester, myTrainer: null);

      expect(find.byKey(const Key('gym-trainer-line-mine')), findsNothing);
      expect(find.text('상세보기'), findsNothing);
    });
  });

  group('헬스장 찾기 목록의 소속 트레이너 (#1185)', () {
    testWidgets('카드마다 그 헬스장 트레이너를 전원 적는다', (WidgetTester tester) async {
      await pumpGymTab(tester, hasMyGym: false);

      expect(find.byKey(const Key('gym-trainer-trainer-kim')), findsOneWidget);
      expect(find.byKey(const Key('gym-trainer-trainer-park')), findsOneWidget);
      expect(find.text('퍼스널 트레이너'), findsOneWidget);
      expect(find.text('재활 트레이너'), findsOneWidget);
      expect(find.text('추천 이유: 혈압 관리와 운동 병행 지도'), findsOneWidget);
      // 아직 아무와도 연결되지 않았다 — 배지는 뜨지 않는다.
      expect(find.text('연결됨'), findsNothing);
    });
  });

  group('지도·목록 드래그 시트 (#1186 · #1274)', () {
    final Finder sheet = find.byKey(const Key('gym-result-sheet'));
    final Finder toggle = find.byKey(const ValueKey<String>('gym-list-toggle'));

    /// 지도의 윗변. 시트를 어디로 옮기든 이 값은 그대로여야 한다.
    double mapTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(KakaoMapView).first).dy;

    /// 시트의 윗변 — 지금 시트가 어디에 붙어 있는지를 이 값으로 읽는다.
    /// 작을수록 시트가 높이 올라와 목록이 많이 보인다.
    double sheetTop(WidgetTester tester) => tester.getTopLeft(sheet).dy;

    testWidgets('처음에는 지도와 목록이 함께 보인다', (WidgetTester tester) async {
      await pumpGymTab(tester, hasMyGym: false);

      expect(toggle, findsOneWidget);
      expect(find.text(_gym.name), findsWidgets);
      expect(find.text('1개 결과'), findsOneWidget);
      expect(find.byType(KakaoMapView), findsOneWidget);
    });

    testWidgets('위로 끌면 목록만, 아래로 끌면 지도만 남는다', (WidgetTester tester) async {
      await pumpGymTab(tester, hasMyGym: false);
      final double middle = sheetTop(tester);

      await tester.drag(sheet, const Offset(0, -400));
      await tester.pumpAndSettle();
      final double top = sheetTop(tester);
      expect(top, lessThan(middle), reason: '위로 끌었는데 시트가 올라오지 않았다');

      await tester.drag(sheet, const Offset(0, 700));
      await tester.pumpAndSettle();
      final double bottom = sheetTop(tester);
      expect(bottom, greaterThan(middle), reason: '아래로 끌었는데 시트가 내려가지 않았다');
      // 지도만 남은 자리에서도 다시 올릴 머리줄은 보인다.
      expect(find.text('주변 헬스장'), findsOneWidget);
      expect(toggle, findsOneWidget);
    });

    testWidgets('짧게 끌고 손을 떼면 가장 가까운 단계에 붙는다', (WidgetTester tester) async {
      await pumpGymTab(tester, hasMyGym: false);
      final double middle = sheetTop(tester);

      // 어정쩡한 거리만 끌고 놓는다 — 그 자리에 멈추면 안 된다.
      await tester.drag(sheet, const Offset(0, -40));
      await tester.pumpAndSettle();

      expect(sheetTop(tester), middle);
    });

    testWidgets('시트를 옮겨도 지도는 제자리다', (WidgetTester tester) async {
      await pumpGymTab(tester, hasMyGym: false);
      final double before = mapTop(tester);

      await tester.drag(sheet, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(mapTop(tester), before);

      await tester.drag(sheet, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(mapTop(tester), before);
    });

    testWidgets('화살표와 드래그가 같은 자리를 가리킨다', (WidgetTester tester) async {
      await pumpGymTab(tester, hasMyGym: false);

      // 손으로 맨 아래까지 내린다 — 화살표는 이제 위를 가리켜야 한다.
      await tester.drag(sheet, const Offset(0, 700));
      await tester.pumpAndSettle();
      final double bottom = sheetTop(tester);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: toggle, matching: find.byType(Icon)),
            )
            .icon,
        Icons.keyboard_arrow_up_rounded,
      );

      // 그 화살표를 누르면 반반 자리로 돌아온다.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(sheetTop(tester), lessThan(bottom));
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: toggle, matching: find.byType(Icon)),
            )
            .icon,
        Icons.keyboard_arrow_down_rounded,
      );
    });
  });
}
