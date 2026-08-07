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
}
