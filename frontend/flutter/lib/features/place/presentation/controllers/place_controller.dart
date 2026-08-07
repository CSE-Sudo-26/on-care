import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/place/data/repositories/dio_place_repository.dart';
import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/domain/entities/place_query.dart';
import 'package:oncare/features/place/domain/repositories/place_repository.dart';

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => DioPlaceRepository(ref.watch(dioProvider)),
  name: 'placeRepository',
);

/// Current map centre + filter. Panning the map or picking a category updates
/// this, which refetches [nearbyPlacesProvider].
final placeQueryProvider = StateProvider<PlaceQuery>(
  (ref) => const PlaceQuery(),
  name: 'placeQuery',
);

final nearbyPlacesProvider = FutureProvider<List<Place>>((ref) {
  final query = ref.watch(placeQueryProvider);
  return ref.watch(placeRepositoryProvider).nearbyPlaces(query);
}, name: 'nearbyPlaces');
