import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';

import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/domain/entities/place_query.dart';
import 'package:oncare/features/place/domain/repositories/place_repository.dart';
import 'package:oncare/features/place/presentation/controllers/place_controller.dart';

/// `local_api_interceptor` 의 데모 픽스처와 같은 카카오 실데이터(id 포함).
class _KakaoFixtureRepository implements PlaceRepository {
  const _KakaoFixtureRepository();

  @override
  Future<List<Place>> nearbyPlaces(PlaceQuery query) async => const <Place>[
    Place(
      id: '11621774',
      name: '휘트니스에이든',
      category: PlaceCategory.fitness,
      address: '서울 마포구 신촌로 92',
      distanceMeters: 127,
      lat: 37.5551767483122,
      lng: 126.935686079639,
    ),
    Place(
      id: '1558845892',
      name: '하이핏',
      category: PlaceCategory.fitness,
      address: '서울 서대문구 연세로4길 19',
      distanceMeters: 186,
      lat: 37.5573727191112,
      lng: 126.937816432934,
    ),
    Place(
      id: '328969863',
      name: '빌드업짐 PT 신촌점',
      category: PlaceCategory.fitness,
      address: '서울 서대문구 연세로4길 1',
      distanceMeters: 133,
      lat: 37.5570723299884,
      lng: 126.937142154792,
    ),
    Place(
      id: '696444256',
      name: '신인규피티스튜디오',
      category: PlaceCategory.fitness,
      address: '서울 서대문구 명물길 10',
      distanceMeters: 177,
      lat: 37.5573851891011,
      lng: 126.937543667755,
    ),
  ];
}

/// 카카오가 실패해도 제휴 목록은 남아야 한다(#329 폴백 요건).
class _FailingPlaceRepository implements PlaceRepository {
  const _FailingPlaceRepository();

  @override
  Future<List<Place>> nearbyPlaces(PlaceQuery query) async =>
      throw StateError('kakao down');
}

/// [useMockApi] 가 시연용 보강 데이터를 붙일지 정한다 — 실 API 응답에는 붙지 않아야
/// 한다(지어낸 값이 실재 업체의 사실 정보처럼 보이면 안 된다).
ProviderContainer _containerWith(
  PlaceRepository repo, {
  bool useMockApi = true,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      placeRepositoryProvider.overrideWithValue(repo),
      appConfigProvider.overrideWithValue(
        AppConfig(
          environment: Environment.dev,
          apiBaseUrl: 'http://localhost',
          useMockApi: useMockApi,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('헬스장 찾기는 제휴 3곳 + 카카오 4곳 = 7곳을 준다', () async {
    final container = _containerWith(const _KakaoFixtureRepository());
    final gyms = await container.read(gymFinderResultsProvider.future);

    expect(gyms.length, 7);
    // 제휴가 앞에 온다 — 트레이너·평점이 있는 쪽을 먼저 노출한다.
    expect(gyms.first.name, '온케어짐 신촌점');
  });

  test('이름이 서로 헷갈리지 않는다 (#329 리뷰 지적)', () async {
    final container = _containerWith(const _KakaoFixtureRepository());
    final gyms = await container.read(gymFinderResultsProvider.future);

    final names = gyms.map((Gym g) => g.name).toList();
    expect(names.toSet().length, names.length, reason: '중복 이름 없음');
    // 한 이름이 다른 이름을 통째로 포함하면 목록에서 구별되지 않는다
    // (예전 '온케어 피트니스' / '온케어 피트니스 신촌점').
    for (final String a in names) {
      for (final String b in names) {
        if (a == b) continue;
        expect(b.contains(a), isFalse, reason: '"$b" 안에 "$a" 가 그대로 들어 있다');
      }
    }
  });

  test('카카오 헬스장에 상세용 정보가 채워진다', () async {
    final container = _containerWith(const _KakaoFixtureRepository());
    final gyms = await container.read(gymFinderResultsProvider.future);
    final Gym buildUp = gyms.firstWhere((Gym g) => g.id == '328969863');

    // 카카오 실데이터
    expect(buildUp.name, '빌드업짐 PT 신촌점');
    expect(buildUp.address, '서울 서대문구 연세로4길 1');
    expect(buildUp.distanceKm, closeTo(0.133, 0.001));
    expect(buildUp.hasCoordinates, isTrue);
    // 카카오가 주지 않아 데모 프로필에서 채우는 값 — 상세 화면이 이걸 렌더한다
    expect(buildUp.rating, greaterThan(0));
    expect(buildUp.tags, isNotEmpty);
    expect(buildUp.phone, isNotNull);
    expect(buildUp.weekdayHours, isNotNull);
  });

  test('실 API 모드에서는 시연용 값을 붙이지 않는다', () async {
    // 지어낸 평점·전문분야·영업시간이 실재 업체의 사실 정보처럼 보이면 안 된다.
    final container = _containerWith(
      const _KakaoFixtureRepository(),
      useMockApi: false,
    );
    final gyms = await container.read(gymFinderResultsProvider.future);
    final Gym buildUp = gyms.firstWhere((Gym g) => g.id == '328969863');

    // 카카오가 준 값은 그대로 남는다
    expect(buildUp.name, '빌드업짐 PT 신촌점');
    expect(buildUp.hasCoordinates, isTrue);
    // 지어낸 값은 붙지 않는다 (평점 0 이면 UI 가 뱃지를 감춘다)
    expect(buildUp.rating, 0);
    expect(buildUp.tags, isEmpty);
    expect(buildUp.phone, isNull);
    expect(buildUp.weekdayHours, isNull);
  });

  test('카카오 헬스장에도 소속 트레이너가 붙는다', () async {
    // 트레이너는 Gym 이 아니라 Trainer 에 있고 gymId(= 카카오 place id)로 이어진다.
    final container = _containerWith(const _KakaoFixtureRepository());
    final trainers = await container.read(
      gymTrainersProvider('328969863').future,
    );

    expect(trainers, isNotEmpty);
    expect(trainers.every((Trainer t) => t.gymId == '328969863'), isTrue);
  });

  test('모든 헬스장이 지도 핀을 찍을 좌표를 갖는다', () async {
    final container = _containerWith(const _KakaoFixtureRepository());
    final gyms = await container.read(gymFinderResultsProvider.future);

    expect(gyms.every((Gym g) => g.hasCoordinates), isTrue);
  });

  test('카카오가 실패해도 제휴 헬스장은 남는다', () async {
    final container = _containerWith(const _FailingPlaceRepository());
    final gyms = await container.read(gymFinderResultsProvider.future);

    expect(gyms.length, 3);
    expect(gyms.every((Gym g) => g.rating > 0), isTrue);
  });
}
