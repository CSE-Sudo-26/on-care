import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/my_reservation.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/entities/trainer_slot.dart';

/// Gym + trainer directory, plus the user's own two links. Both live here
/// because the links are coupled: leaving a gym also drops its trainer.
abstract class GymRepository {
  /// User's current gym (one). `null` until they register one.
  Future<Gym?> fetchMyGym();

  /// Nearby gyms shown in the "헬스장 찾기" finder sheet.
  Future<List<Gym>> fetchNearby();

  /// Drops the gym link, and the trainer with it — you cannot keep a trainer
  /// at a gym you left. [fetchMyGym] and [fetchMyTrainer] both return `null`
  /// after this.
  Future<void> disconnectMyGym();

  /// User's assigned trainer (one). `null` when unassigned.
  Future<Trainer?> fetchMyTrainer();

  /// Every trainer working at [gymId]. Empty when the gym has none.
  Future<List<Trainer>> fetchTrainersByGym(String gymId);

  /// Whole trainer directory, for the "트레이너 찾기" list page.
  Future<List<Trainer>> fetchAllTrainers();

  /// One trainer by their own id, `null` when not found.
  Future<Trainer?> fetchTrainer(String trainerId);

  /// Trainers suggested in the 추천 트레이너 rail, across gyms.
  Future<List<Trainer>> fetchRecommendedTrainers();

  /// Drops only the trainer link; the gym link stays. No-op when unassigned.
  Future<void> disconnectMyTrainer();

  /// Bookable times for one trainer, earliest first. Past slots are already
  /// filtered out; booked-out ones are kept so the day reads as full rather
  /// than empty.
  Future<List<TrainerSlot>> fetchSlots(String trainerId);

  /// Takes one place in [slotId].
  ///
  /// Throws [StateError] when the slot is unknown or already booked out, so a
  /// stale screen cannot silently overbook.
  Future<void> reserve(String slotId);

  /// 내가 잡아 둔 예약들. 예약 패널이 '내 자리'를 표시하고 취소를 걸 근거다. (#502)
  Future<List<MyReservation>> fetchMyReservations();

  /// 예약 취소. 좌석과 트레이너 일정이 함께 돌아간다.
  ///
  /// 이미 시작한 수업이거나 남의 예약이면 [StateError] — 예약 실패와 같은 규칙으로,
  /// 목과 실서버가 같은 예외를 낸다.
  Future<void> cancelReservation(String reservationId);
}
