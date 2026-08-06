import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';

/// In-memory gym data matching the prototype's `GymCard` / `GymFinder`
/// mocks. The user's "my gym" starts as 온케어짐 신촌점 — the same gym the
/// trainer app's `seedTrainerProfile` belongs to, so both apps describe one
/// relationship. The finder sheet returns three 신촌 권역 candidates with
/// ratings, tags, and distances.
///
/// Stateful (not const) so [disconnectMyGym] / [disconnectMyTrainer] can
/// clear the links for the session — the provider holds one instance, so
/// MY 탭과 운동 탭이 같은 연결 상태를 본다.
class MockGymRepository implements GymRepository {
  MockGymRepository();

  /// 연결된 헬스장. 트레이너만 해제하면 [_sinchonNoTrainer] 로 바뀐다.
  Gym? _myGym = _sinchon;

  /// 트레이너 앱 `seedTrainerProfile.gym` 과 같은 값이어야 한다.
  static const Gym _sinchon = Gym(
    id: 'gym-oncare-sinchon',
    name: '온케어짐 신촌점',
    address: '서울 서대문구 신촌로 120',
    distanceKm: 0.8,
    rating: 4.7,
    tags: <String>['다이어트', '재활운동'],
    trainerName: '김트레이너',
    trainerRole: '퍼스널 트레이너',
    weekdayHours: '06:00 - 23:00',
    weekendHours: '08:00 - 20:00',
    phone: '02-1234-5678',
  );

  /// 같은 헬스장이지만 담당 트레이너 연결만 없는 상태.
  static const Gym _sinchonNoTrainer = Gym(
    id: 'gym-oncare-sinchon',
    name: '온케어짐 신촌점',
    address: '서울 서대문구 신촌로 120',
    distanceKm: 0.8,
    rating: 4.7,
    tags: <String>['다이어트', '재활운동'],
    weekdayHours: '06:00 - 23:00',
    weekendHours: '08:00 - 20:00',
    phone: '02-1234-5678',
  );

  static const Gym _healthmate = Gym(
    id: 'gym-healthmate',
    name: '헬스메이트 신촌점',
    address: '서울 서대문구 신촌로 83',
    distanceKm: 1.2,
    rating: 4.5,
    tags: <String>['근력운동', '만성질환 관리'],
    trainerName: '강트레이너',
    trainerReason: '교대근무 스케줄 케어 경험이 풍부해요',
    weekdayHours: '05:30 - 24:00',
    weekendHours: '07:00 - 22:00',
    phone: '02-2345-6789',
  );

  static const Gym _bodyAndSoul = Gym(
    id: 'gym-bodyandsoul',
    name: '바디앤소울 피트니스',
    address: '서울 마포구 백범로 23',
    distanceKm: 1.5,
    rating: 4.8,
    tags: <String>['PT', '식단 상담'],
    trainerName: '이트레이너',
    trainerReason: '간단한 운동 루틴에 특화되어 있어요',
    weekdayHours: '06:00 - 22:00',
    weekendHours: '09:00 - 18:00',
    phone: '02-3456-7890',
  );

  @override
  Future<Gym?> fetchMyGym() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return _myGym;
  }

  @override
  Future<List<Gym>> fetchNearby() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final Gym? myGym = _myGym;
    return <Gym>[
      if (myGym?.id == _sinchon.id) myGym! else _sinchon,
      _healthmate,
      _bodyAndSoul,
    ];
  }

  @override
  Future<void> disconnectMyGym() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // 헬스장을 떠나면 그곳 소속 트레이너 연결도 함께 사라진다.
    _myGym = null;
  }

  @override
  Future<void> disconnectMyTrainer() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // 헬스장 연결은 그대로 두고 담당 트레이너만 뗀다.
    if (_myGym == null) return;
    _myGym = _sinchonNoTrainer;
  }
}
