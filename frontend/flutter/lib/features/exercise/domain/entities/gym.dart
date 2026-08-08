/// Membership / candidate gym used by the 헬스장 tab of the exercise page.
/// Mirrors the prototype's `GymCard` + `GymFinder` data shape: card list
/// with rating, distance, tags, and hours.
///
/// Trainers are not part of this entity — a gym employs several of them, so
/// they live in `Trainer` keyed by [id]. Fetch them with
/// `GymRepository.fetchTrainersByGym`.
class Gym {
  const Gym({
    required this.id,
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.rating,
    required this.tags,
    this.weekdayHours,
    this.weekendHours,
    this.phone,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String address;
  final double distanceKm;
  final double rating;
  final List<String> tags;
  final String? weekdayHours;
  final String? weekendHours;
  final String? phone;

  /// 지도 핀 좌표. 좌표를 모르는 헬스장은 목록에만 뜨고 핀은 생략된다
  /// (제휴 데이터가 `/gyms/*` 로 옮겨가기 전까지는 비어 있을 수 있다 — #324).
  final double? lat;
  final double? lng;

  bool get hasCoordinates => lat != null && lng != null;
}
