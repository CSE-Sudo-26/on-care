/// 헬스장 찾기 화면의 지도와 결과 시트. (#865 → #1135 → #1274)
///
/// 지도는 **자리에 고정**되고 그 위로 목록 시트가 오르내린다. 목록을 밀어도
/// 지도는 움직이지 않는다 — 예전에 지도까지 함께 밀려 올라가던 것이 이
/// 화면에서 가장 다루기 나빴던 부분이다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/pages/gym_list_page.dart';
import 'package:oncare/features/exercise/presentation/widgets/kakao_map/kakao_map_view.dart';
import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/domain/entities/place_query.dart';
import 'package:oncare/features/place/domain/repositories/place_repository.dart';
import 'package:oncare/features/place/presentation/controllers/place_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 카카오가 아무 결과도 주지 않아도 제휴 목록만으로 화면이 선다(#329).
class _EmptyPlaceRepository implements PlaceRepository {
  const _EmptyPlaceRepository();

  @override
  Future<List<Place>> nearbyPlaces(PlaceQuery query) async => const <Place>[];
}

Future<void> _pumpFinder(WidgetTester tester, {Size? size}) async {
  await tester.binding.setSurfaceSize(size ?? const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        placeRepositoryProvider.overrideWithValue(
          const _EmptyPlaceRepository(),
        ),
        gymRepositoryProvider.overrideWithValue(MockGymRepository()),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: Environment.dev,
            apiBaseUrl: 'http://localhost',
            useMockApi: true,
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GymListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 지도의 윗변. 목록을 밀어도 이 값은 그대로여야 한다.
double _mapTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(KakaoMapView).first).dy;

void main() {
  testWidgets('지도와 결과가 함께 보인다', (tester) async {
    await _pumpFinder(tester);

    expect(find.byType(KakaoMapView), findsOneWidget);
    // 결과 개수와 정렬 줄, 그리고 카드가 함께 읽힌다.
    expect(find.textContaining('개'), findsWidgets);
    expect(find.text('주변 헬스장'), findsOneWidget);
    // 처음 자리는 반반이다 — 지도와 목록이 함께 읽힌다 (#1274).
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });

  testWidgets('목록을 밀어도 지도는 제자리다 (#1135)', (tester) async {
    await _pumpFinder(tester);
    final double before = _mapTop(tester);

    await tester.drag(
      find.byKey(const Key('gym-result-sheet')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(_mapTop(tester), before, reason: '목록을 밀었더니 지도까지 따라 올라갔다');
  });

  testWidgets('시트는 화면 가로를 다 쓰고 지도와 겹치지 않는다 (#1362)', (tester) async {
    await _pumpFinder(tester);

    // `주변 헬스장` 은 화면 아래에 붙는 창이라 지도 폭에 맞춰 들여쓰지 않는다.
    final Finder sheet = find.byKey(const Key('gym-result-sheet'));
    expect(tester.getSize(sheet).width, 390);

    // 지도와 시트가 겹치는 자리가 있으면, 웹에서 시트 위의 터치가 아래 지도
    // (플랫폼 뷰)로 새어 나가 시트를 끌 수도 목록을 밀 수도 없게 된다.
    Rect map() => tester.getRect(find.byType(KakaoMapView).first);
    expect(map().bottom, lessThanOrEqualTo(tester.getTopLeft(sheet).dy + 0.5));

    // 시트를 끌어 올린 뒤에도 겹치지 않는다 — 지도는 시트가 남긴 자리만큼만
    // 차지한다.
    await tester.drag(sheet, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(map().bottom, lessThanOrEqualTo(tester.getTopLeft(sheet).dy + 0.5));
  });

  testWidgets('검색 결과가 없으면 빈 문구가 그 자리에 뜬다', (tester) async {
    await _pumpFinder(tester);

    await tester.enterText(find.byType(TextField).first, '없는이름123');
    await tester.pumpAndSettle();

    expect(find.text('검색 결과가 없어요.'), findsOneWidget);
    // 지도는 그대로 남는다 — 결과가 없다고 화면이 비지 않는다.
    expect(find.byType(KakaoMapView), findsOneWidget);
  });

  testWidgets('작은 화면에서도 넘치지 않는다', (tester) async {
    await _pumpFinder(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
