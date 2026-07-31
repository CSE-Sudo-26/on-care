import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';

/// In-memory gym data matching the prototype's `GymCard` / `GymFinder`
/// mocks. The user's "my gym" starts as 강남 피트니스 센터; the finder
/// sheet returns three candidates with ratings, tags, and distances.
class MockGymRepository implements GymRepository {
  const MockGymRepository();

  static const Gym _gangnam = Gym(
    id: 'gym-gangnam',
    name: '강남 피트니스 센터',
    address: '서울시 강남구 역삼동 123-45',
    distanceKm: 0.8,
    rating: 4.7,
    tags: <String>['다이어트', '재활운동'],
    trainerName: '김트레이너',
    trainerRole: '전담 트레이너',
    weekdayHours: '06:00 - 23:00',
    weekendHours: '08:00 - 20:00',
    phone: '02-1234-5678',
  );

  static const Gym _healthmate = Gym(
    id: 'gym-healthmate',
    name: '헬스메이트 역삼점',
    address: '서울시 강남구 역삼동 456-78',
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
    address: '서울시 강남구 논현동 789-01',
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
    return _gangnam;
  }

  @override
  Future<List<Gym>> fetchNearby() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return const <Gym>[_gangnam, _healthmate, _bodyAndSoul];
  }
}
