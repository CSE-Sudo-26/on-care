/// Membership / candidate gym used by the 헬스장 tab of the exercise page.
/// Mirrors the prototype's `GymCard` + `GymFinder` data shape: card list
/// with rating, distance, tags, hours, and optional trainer details.
class Gym {
  const Gym({
    required this.id,
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.rating,
    required this.tags,
    this.trainerName,
    this.trainerRole,
    this.trainerReason,
    this.trainerCareer,
    this.trainerIntro,
    this.trainerCertifications = const <String>[],
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
  final String? trainerName;
  final String? trainerRole;

  /// Per-trainer recommendation reason shown on the 추천 트레이너 card/detail.
  /// Null falls back to the generic localized reason.
  final String? trainerReason;

  /// Years of experience as free text (e.g. "7년"), mirroring the trainer
  /// app's `TrainerProfile.career`. Null hides the row.
  final String? trainerCareer;

  /// Self-introduction shown on the trainer detail page, mirroring the
  /// trainer app's `TrainerProfile.intro`. Null hides the section.
  final String? trainerIntro;

  /// Licences and certifications, mirroring the trainer app's
  /// `TrainerProfile.certifications`. Empty hides the section.
  final List<String> trainerCertifications;
  final String? weekdayHours;
  final String? weekendHours;
  final String? phone;
}
