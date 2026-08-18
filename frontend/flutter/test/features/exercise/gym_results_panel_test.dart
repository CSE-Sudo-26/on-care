/// 헬스장 찾기의 검색 결과 패널. (#865)
///
/// 예전에는 지도 아래 좁은 칸에서만 목록이 스크롤돼, 결과가 여러 개면 그 칸
/// 안에서 계속 굴려야 했다. 이제 결과 영역을 위로 끌어 넓힐 수 있되 **완전히
/// 접히지는 않는다** — 결과가 있다는 사실과 첫 카드는 언제나 보여야 한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/pages/gym_list_page.dart';
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

/// 패널의 윗변. `DraggableScrollableSheet` 자체는 배치 영역 전체를 차지하므로
/// 실제로 움직이는 것은 그 안의 스크롤 뷰다.
double _panelTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CustomScrollView).first).dy;

double _sheetHeightFraction(WidgetTester tester) {
  final Rect sheet = tester.getRect(find.byType(CustomScrollView).first);
  return sheet.height / tester.getSize(find.byType(GymListPage)).height;
}

void main() {
  testWidgets('최소 상태에서 지도와 결과가 함께 보인다', (tester) async {
    await _pumpFinder(tester);

    // 결과 개수와 정렬 줄, 그리고 카드가 최소 상태에서도 읽힌다.
    expect(find.textContaining('개'), findsWidgets);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    // 패널이 화면 전부를 덮지 않는다 — 위쪽에 지도가 남아 있다.
    expect(_sheetHeightFraction(tester), lessThan(0.6));
  });

  testWidgets('위로 끌면 결과 영역이 넓어진다', (tester) async {
    await _pumpFinder(tester);
    final double before = _panelTop(tester);

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(
      _panelTop(tester),
      lessThan(before),
      reason: '패널이 위로 확장되지 않았다',
    );
  });

  testWidgets('아래로 끌어도 최소 높이 아래로는 내려가지 않는다', (tester) async {
    await _pumpFinder(tester);
    final double atMin = _panelTop(tester);

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(
      _panelTop(tester),
      closeTo(atMin, 1),
      reason: '패널이 최소 높이 아래로 내려갔다',
    );
    // 접힌 뒤에도 결과가 있다는 사실이 보여야 한다.
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('검색으로 결과가 바뀌어도 패널 구조는 그대로다', (tester) async {
    await _pumpFinder(tester);

    await tester.enterText(find.byType(TextField).first, '없는이름123');
    await tester.pumpAndSettle();

    expect(find.text('검색 결과가 없어요.'), findsOneWidget);
    // 빈 결과에서도 패널은 남는다 — 사라지면 끌 자리가 없어진다.
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });

  testWidgets('작은 화면에서도 넘치지 않는다', (tester) async {
    await _pumpFinder(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
