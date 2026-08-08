import 'package:dio/dio.dart';

import 'package:oncare/features/place/domain/entities/place.dart';
import 'package:oncare/features/place/domain/entities/place_query.dart';
import 'package:oncare/features/place/domain/repositories/place_repository.dart';

class DioPlaceRepository implements PlaceRepository {
  DioPlaceRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<Place>> nearbyPlaces(PlaceQuery query) async {
    final res = await _dio.get<List<Object?>>(
      '/places/nearby',
      queryParameters: <String, Object?>{
        'lat': query.lat,
        'lng': query.lng,
        'radius_m': query.radiusMeters,
        // Omitted entirely when null — the backend treats a missing
        // `category` as "every category".
        if (query.category != null) 'category': categoryToWire(query.category!),
      },
    );
    final rows = res.data ?? const <Object?>[];
    return rows.cast<Map<String, Object?>>().map(Place.fromJson).toList();
  }
}
