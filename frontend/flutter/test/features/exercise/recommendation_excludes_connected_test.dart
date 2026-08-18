/// 이미 연결된 대상은 추천 후보에서 뺀다. (#864)
///
/// 추천 영역이 답하는 질문은 "새로 연결할 만한 곳이 어디인가" 다. 이미 연결된
/// 헬스장·담당 트레이너가 거기 다시 서면 "연결이 된 것이 맞나" 를 되묻게 된다.
/// 내 헬스장·담당 트레이너 카드에는 그대로 보이므로 정보가 사라지지는 않는다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';

/// 연결 정보 조회만 실패하는 저장소 — 추천까지 함께 무너지는지 본다.
class _BrokenLinkGymRepository extends MockGymRepository {
  @override
  Future<Gym?> fetchMyGym() async => throw Exception('내 헬스장 조회 실패');

  @override
  Future<Trainer?> fetchMyTrainer() async => throw Exception('담당 조회 실패');
}

ProviderContainer _containerWith(MockGymRepository repository) {
  final container = ProviderContainer(
    overrides: <Override>[
      gymRepositoryProvider.overrideWithValue(repository),
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: Environment.dev,
          apiBaseUrl: 'http://localhost',
          useMockApi: true,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('연결된 헬스장은 추천 목록에 없고, 나머지는 그대로다', () async {
    final repository = MockGymRepository();
    final container = _containerWith(repository);

    final Gym? mine = await container.read(myGymProvider.future);
    expect(mine, isNotNull, reason: '데모는 연결된 헬스장으로 시작한다');

    final List<Gym> all = await container.read(nearbyGymsProvider.future);
    final List<Gym> recommended = await container.read(
      recommendedGymsProvider.future,
    );

    expect(recommended.where((Gym gym) => gym.id == mine!.id), isEmpty);
    expect(recommended.length, all.length - 1);
    // 연결되지 않은 후보는 하나도 빠지지 않는다.
    expect(
      recommended.map((Gym gym) => gym.id).toSet(),
      all.map((Gym gym) => gym.id).toSet()..remove(mine!.id),
    );
  });

  test('담당 트레이너는 추천에서 빠지고 같은 헬스장 동료는 남는다', () async {
    final repository = MockGymRepository();
    final container = _containerWith(repository);

    final Trainer? assigned = await container.read(myTrainerProvider.future);
    expect(assigned, isNotNull, reason: '데모는 담당 트레이너로 시작한다');

    final List<Trainer> recommended = await container.read(
      recommendedTrainersProvider.future,
    );
    expect(
      recommended.where((Trainer t) => t.id == assigned!.id),
      isEmpty,
      reason: '담당 트레이너가 추천에 남아 있다',
    );

    // 같은 헬스장의 다른 트레이너까지 지우면 탐색이 막힌다 — 그들은 남아야 한다.
    final List<Trainer> sameGym = await container.read(
      gymTrainersProvider(assigned!.gymId).future,
    );
    final Iterable<Trainer> colleagues = sameGym.where(
      (Trainer t) => t.id != assigned.id,
    );
    if (colleagues.isNotEmpty) {
      final Set<String> recommendedIds = recommended
          .map((Trainer t) => t.id)
          .toSet();
      expect(
        colleagues.any((Trainer t) => recommendedIds.contains(t.id)),
        isTrue,
        reason: '같은 헬스장 동료까지 추천에서 사라졌다',
      );
    }
  });

  test('연결을 해제하면 그 대상이 다시 추천 후보가 된다', () async {
    final repository = MockGymRepository();
    final container = _containerWith(repository);

    final Gym? mine = await container.read(myGymProvider.future);
    final Trainer? assigned = await container.read(myTrainerProvider.future);
    expect(mine, isNotNull);
    expect(assigned, isNotNull);

    await repository.disconnectMyGym();
    container
      ..invalidate(myGymProvider)
      ..invalidate(myTrainerProvider)
      ..invalidate(recommendedGymsProvider)
      ..invalidate(recommendedTrainersProvider);

    final List<Gym> gyms = await container.read(recommendedGymsProvider.future);
    expect(
      gyms.where((Gym gym) => gym.id == mine!.id),
      isNotEmpty,
      reason: '해제한 헬스장이 다시 후보가 되지 않았다',
    );

    final List<Trainer> trainers = await container.read(
      recommendedTrainersProvider.future,
    );
    expect(
      trainers.where((Trainer t) => t.id == assigned!.id),
      isNotEmpty,
      reason: '해제한 트레이너가 다시 후보가 되지 않았다',
    );
  });

  test('연결 정보 조회가 실패해도 추천은 살아 있다', () async {
    final container = _containerWith(_BrokenLinkGymRepository());

    // 걸러지지 않은 목록이, 아무것도 없는 화면보다 낫다.
    final List<Gym> gyms = await container.read(recommendedGymsProvider.future);
    expect(gyms, isNotEmpty);
    final List<Trainer> trainers = await container.read(
      recommendedTrainersProvider.future,
    );
    expect(trainers, isNotEmpty);
  });
}
