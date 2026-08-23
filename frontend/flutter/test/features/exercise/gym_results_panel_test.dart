/// 헬스장 찾기 화면의 지도와 결과 목록. (#865 → #1135)
///
/// 지도 위에 결과 시트를 얹어 두던 때에는, 목록을 밀면 시트가 먼저 커지며
/// 지도까지 함께 밀려 올라갔다. 지금은 **지도가 자리에 고정**되고 그 아래
/// 목록만 스크롤한다. 목록을 상자로 한 번 더 감싸지도 않는다.
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
    // 지도를 덮던 시트는 없다 (#1135).
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('목록을 밀어도 지도는 제자리다 (#1135)', (tester) async {
    await _pumpFinder(tester);
    final double before = _mapTop(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(
      _mapTop(tester),
      before,
      reason: '목록을 밀었더니 지도까지 따라 올라갔다',
    );
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
