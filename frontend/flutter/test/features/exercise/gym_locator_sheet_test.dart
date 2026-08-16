import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/exercise_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 제휴 헬스장 — `MockGymRepository` 와 같이 좌표가 없다.
const Gym _withoutCoordinates = Gym(
  id: 'gym-no-coords',
  name: '좌표없는 헬스장',
  address: '서울시 서대문구 신촌로 1',
  distanceKm: 0.4,
  rating: 4.7,
  tags: <String>['PT'],
);

/// 카카오 Local 이 준 헬스장 — 좌표가 있다.
const Gym _withCoordinates = Gym(
  id: 'gym-with-coords',
  name: '좌표있는 헬스장',
  address: '서울시 서대문구 신촌로 2',
  distanceKm: 0.9,
  rating: 0,
  tags: <String>[],
  lat: 37.5559,
  lng: 126.9368,
);

void main() {
  Future<void> openSheet(WidgetTester tester, List<Gym> gyms) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gymFinderResultsProvider.overrideWith((ref) async => gyms),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showGymLocatorSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  AppLocalizations localizations(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  testWidgets('좌표가 없는 헬스장만 있어도 시트가 뜨고 지도 자리가 남는다', (
    WidgetTester tester,
  ) async {
    // 마커 목록은 폴백으로 떨어지기 전에 만들어지므로, 좌표 없는 헬스장을
    // 걸러내지 않으면 여기서 터진다.
    await openSheet(tester, const <Gym>[_withoutCoordinates]);

    expect(tester.takeException(), isNull);
    // 테스트는 web 이 아니라 언제나 폴백 그래픽이 그려진다.
    expect(find.text(localizations(tester).exKakaoMapArea), findsOneWidget);
    expect(find.text(_withoutCoordinates.name), findsOneWidget);
  });

  testWidgets('좌표 유무가 섞여도 결과가 모두 나온다', (WidgetTester tester) async {
    await openSheet(
      tester,
      const <Gym>[_withoutCoordinates, _withCoordinates],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(_withoutCoordinates.name), findsOneWidget);
    // 두 번째 카드는 시트 아래로 밀려 화면 밖이라 skipOffstage 를 끈다 — 여기서
    // 볼 것은 스크롤 위치가 아니라 두 결과가 모두 목록에 올랐는지다.
    expect(
      find.text(_withCoordinates.name, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('검색어로 거르면 지도와 목록이 같은 결과를 가리킨다', (
    WidgetTester tester,
  ) async {
    await openSheet(
      tester,
      const <Gym>[_withoutCoordinates, _withCoordinates],
    );

    await tester.enterText(find.byType(TextField), '좌표있는');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_withoutCoordinates.name), findsNothing);
    expect(find.text(_withCoordinates.name), findsOneWidget);
    // 목록이 하나로 줄어도 지도 자리는 그대로다.
    expect(find.text(localizations(tester).exKakaoMapArea), findsOneWidget);
  });

  testWidgets('결과 카드에 허위 성공을 내는 버튼이 없다 (#787)', (WidgetTester tester) async {
    await openSheet(tester, const <Gym>[_withoutCoordinates]);

    // '건강 요약 전달' 은 확인을 받고 성공 스낵바만 띄웠다 — 보내는 곳이 없었다.
    // 문구가 바뀌어도 잡히도록 '전달' 로 넓게 본다.
    expect(find.textContaining('건강 요약'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('결과 카드를 누르면 헬스장 상세로 간다 (#787)', (WidgetTester tester) async {
    await openSheet(tester, const <Gym>[_withoutCoordinates]);

    // 죽은 자리로 두지 않고, 실제로 동작하는 다음 걸음으로 바꿨다.
    expect(
      find.byKey(Key('gym-result-${_withoutCoordinates.id}')),
      findsOneWidget,
    );
    expect(
      find.text(localizations(tester).exGymDetailHint),
      findsOneWidget,
    );
  });
}
