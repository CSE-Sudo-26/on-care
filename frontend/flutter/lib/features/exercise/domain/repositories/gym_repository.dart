import 'package:oncare/features/exercise/domain/entities/gym.dart';

abstract class GymRepository {
  /// User's current gym (one). `null` until they register one.
  Future<Gym?> fetchMyGym();

  /// Nearby gyms shown in the "헬스장 찾기" finder sheet.
  Future<List<Gym>> fetchNearby();

  /// Drops the gym link, and the trainer with it — you cannot keep a trainer
  /// at a gym you left. [fetchMyGym] returns `null` after this.
  Future<void> disconnectMyGym();

  /// Drops only the trainer link. [fetchMyGym] still returns the gym, with
  /// its trainer fields cleared. No-op when no gym is connected.
  Future<void> disconnectMyTrainer();
}
