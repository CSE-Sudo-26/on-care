import 'package:oncare/features/place/domain/entities/place.dart';

/// Search window for `GET /places/nearby`.
///
/// The map centre and the search centre are the same value, so panning the map
/// and refetching the list stay in sync. Defaults match the backend defaults
/// (서울시청) so the seeded demo data stays inside the radius.
class PlaceQuery {
  const PlaceQuery({
    this.lat = 37.5665,
    this.lng = 126.9780,
    this.category,
    this.radiusMeters = 3000,
  });

  final double lat;
  final double lng;

  /// `null` searches every category — matches the backend contract.
  final PlaceCategory? category;
  final int radiusMeters;

  PlaceQuery copyWith({
    double? lat,
    double? lng,
    int? radiusMeters,
    // Nullable field, so a sentinel is needed to distinguish "leave as is"
    // from "clear the filter".
    Object? category = _unset,
  }) => PlaceQuery(
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    category: identical(category, _unset)
        ? this.category
        : category as PlaceCategory?,
    radiusMeters: radiusMeters ?? this.radiusMeters,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is PlaceQuery &&
      other.lat == lat &&
      other.lng == lng &&
      other.category == category &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(lat, lng, category, radiusMeters);
}
