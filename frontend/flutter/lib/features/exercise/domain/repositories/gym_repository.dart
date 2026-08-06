import 'package:oncare/features/exercise/domain/entities/gym.dart';

abstract class GymRepository {
  /// User's current gym (one). `null` until they register one.
  Future<Gym?> fetchMyGym();

  /// Nearby gyms shown in the "헬스장 찾기" finder sheet.
  Future<List<Gym>> fetchNearby();

  /// Drops the user's gym/trainer link. [fetchMyGym] returns `null` after this.
  Future<void> disconnectMyGym();
}
