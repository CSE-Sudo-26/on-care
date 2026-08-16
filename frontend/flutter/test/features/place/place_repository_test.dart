import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/place/data/repositories/mock_place_repository.dart';
import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/domain/entities/place_query.dart';

void main() {
  // 장소 계층은 '주변 장소' 화면이 사라진 뒤에도 남는다 — 운동 탭의 헬스장 찾기가
  // 카카오 Local 결과를 이 repository 로 받는다(`gymFinderResultsProvider`).
  // 그래서 목 데이터가 네 분류를 모두 덮는지는 계속 확인할 값이 있다.
  test('MockPlaceRepository 는 모든 분류의 장소를 돌려준다', () async {
    const MockPlaceRepository repo = MockPlaceRepository();

    final List<Place> places = await repo.nearbyPlaces(const PlaceQuery());

    expect(places, isNotEmpty);
    final Set<PlaceCategory> categories = places
        .map((Place p) => p.category)
        .toSet();
    expect(categories, contains(PlaceCategory.medical));
    expect(categories, contains(PlaceCategory.fitness));
    expect(categories, contains(PlaceCategory.healthyFood));
    expect(categories, contains(PlaceCategory.pharmacy));
  });
}
