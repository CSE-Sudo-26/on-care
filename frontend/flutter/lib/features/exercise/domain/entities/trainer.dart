/// A trainer working at a gym. Trainers have their own identity so a gym can
/// employ several of them — [Gym] deliberately carries no trainer fields.
///
/// The profile fields (career/intro/certifications) mirror the trainer app's
/// `TrainerProfile`, so the same person reads the same in both apps.
class Trainer {
  const Trainer({
    required this.id,
    required this.gymId,
    required this.name,
    this.role,
    this.reason,
    this.career,
    this.intro,
    this.certifications = const <String>[],
  });

  final String id;

  /// Gym this trainer belongs to. Several trainers may share one gym id.
  final String gymId;
  final String name;

  /// Job title (e.g. "퍼스널 트레이너"). Null falls back to a localized default.
  final String? role;

  /// Why this trainer is recommended, shown on the 추천 트레이너 card/detail.
  /// Null falls back to the generic localized reason.
  final String? reason;

  /// Years of experience as free text (e.g. "7년"). Null hides the row.
  final String? career;

  /// Self-introduction shown on the detail page. Null hides the section.
  final String? intro;

  /// Licences and certifications. Empty hides the section.
  final List<String> certifications;

  /// True when there is anything to render in the 트레이너 소개 section.
  bool get hasProfile =>
      (intro?.isNotEmpty ?? false) ||
      (career?.isNotEmpty ?? false) ||
      certifications.isNotEmpty;
}
