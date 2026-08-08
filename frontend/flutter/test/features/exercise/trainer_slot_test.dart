import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/trainer_slot.dart';

/// 예약 슬롯은 트레이너에 귀속된다(#426). 예전에는 위젯 안에 슬롯 3개가
/// 하드코딩되어 있어 누구를 예약하든 같은 시간이 떴다.
void main() {
  test('트레이너마다 다른 슬롯을 돌려준다', () async {
    final MockGymRepository repo = MockGymRepository();

    final List<TrainerSlot> kim = await repo.fetchSlots('trainer-kim');
    final List<TrainerSlot> park = await repo.fetchSlots('trainer-park');

    expect(kim, isNotEmpty);
    expect(park, isNotEmpty);
    expect(kim.every((TrainerSlot s) => s.trainerId == 'trainer-kim'), isTrue);
    expect(park.every((TrainerSlot s) => s.trainerId == 'trainer-park'), isTrue);
    // 같은 헬스장 소속이어도 빈 시간이 겹치지 않는다.
    expect(
      kim.map((TrainerSlot s) => s.startsAt).toSet().intersection(
        park.map((TrainerSlot s) => s.startsAt).toSet(),
      ),
      isEmpty,
    );
  });

  test('슬롯은 시작 시각 오름차순이다', () async {
    final List<TrainerSlot> slots = await MockGymRepository().fetchSlots(
      'trainer-kim',
    );

    for (int i = 1; i < slots.length; i++) {
      expect(
        slots[i].startsAt.isBefore(slots[i - 1].startsAt),
        isFalse,
        reason: '슬롯이 시간순으로 정렬돼야 함',
      );
    }
  });

  test('슬롯이 없는 트레이너는 빈 목록이다', () async {
    // 윤트레이너는 빈 상태 화면을 데모에서 보려고 일부러 비워 뒀다.
    expect(await MockGymRepository().fetchSlots('trainer-yoon'), isEmpty);
    expect(await MockGymRepository().fetchSlots('trainer-nope'), isEmpty);
  });

  test('예약하면 잔여 자리가 줄고 다시 조회해도 유지된다', () async {
    final MockGymRepository repo = MockGymRepository();
    final List<TrainerSlot> before = await repo.fetchSlots('trainer-kim');
    final TrainerSlot open = before.firstWhere((TrainerSlot s) => !s.isFull);

    await repo.reserve(open.id);

    final List<TrainerSlot> after = await repo.fetchSlots('trainer-kim');
    final TrainerSlot same = after.firstWhere((TrainerSlot s) => s.id == open.id);
    expect(same.remaining, open.remaining - 1);
    expect(same.capacity, open.capacity, reason: '정원은 그대로여야 함');
  });

  test('마감된 자리는 예약할 수 없다', () async {
    final MockGymRepository repo = MockGymRepository();
    final List<TrainerSlot> slots = await repo.fetchSlots('trainer-kim');
    final TrainerSlot full = slots.firstWhere((TrainerSlot s) => s.isFull);

    expect(full.remaining, 0);
    await expectLater(repo.reserve(full.id), throwsStateError);
  });

  test('마지막 한 자리를 잡으면 그 슬롯이 마감된다', () async {
    final MockGymRepository repo = MockGymRepository();
    final List<TrainerSlot> slots = await repo.fetchSlots('trainer-park');
    // 박트레이너는 1:1 이라 정원이 1이다.
    final TrainerSlot single = slots.firstWhere(
      (TrainerSlot s) => s.capacity == 1 && !s.isFull,
    );

    await repo.reserve(single.id);

    final List<TrainerSlot> after = await repo.fetchSlots('trainer-park');
    expect(after.firstWhere((TrainerSlot s) => s.id == single.id).isFull, isTrue);
    // 같은 자리를 두 번 잡을 수 없다.
    await expectLater(repo.reserve(single.id), throwsStateError);
  });

  test('없는 슬롯 예약은 실패한다', () async {
    await expectLater(
      MockGymRepository().reserve('slot-nope'),
      throwsStateError,
    );
  });

  test('한 저장소의 예약이 다른 트레이너 슬롯을 건드리지 않는다', () async {
    final MockGymRepository repo = MockGymRepository();
    final List<TrainerSlot> parkBefore = await repo.fetchSlots('trainer-park');
    final TrainerSlot kimSlot = (await repo.fetchSlots(
      'trainer-kim',
    )).firstWhere((TrainerSlot s) => !s.isFull);

    await repo.reserve(kimSlot.id);

    final List<TrainerSlot> parkAfter = await repo.fetchSlots('trainer-park');
    expect(
      parkAfter.map((TrainerSlot s) => s.remaining),
      parkBefore.map((TrainerSlot s) => s.remaining),
    );
  });
}
