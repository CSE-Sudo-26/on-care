import 'package:oncare/features/exercise/domain/entities/gym.dart';
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
}
