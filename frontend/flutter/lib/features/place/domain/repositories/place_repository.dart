import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/domain/entities/place_query.dart';

abstract class PlaceRepository {
  /// Nearby places for [query], nearest first.
  Future<List<Place>> nearbyPlaces(PlaceQuery query);
}
