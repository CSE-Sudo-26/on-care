/// The member's assigned trainer (coach) summary — `/me/coach`.
class MemberCoach {
  const MemberCoach({
    required this.trainerId,
    required this.name,
    required this.specialty,
    required this.career,
    required this.intro,
    required this.gymName,
    required this.goal,
  });

  final String trainerId;
  final String name;
  final String specialty;
  final String career;
  final String intro;
  final String gymName;

  /// The coaching goal the trainer set for this member.
  final String goal;
}

/// A routine the member received from their coach — `/me/coach/routines`.
class CoachRoutine {
  const CoachRoutine({
    required this.id,
    required this.name,
    required this.minutes,
    required this.type,
    required this.reason,
    required this.source,
  });

  final String id;
  final String name;
  final int minutes;
  final String type;
  final String reason;

  /// `ai` (AI-suggested) or `trainer` (hand-assigned).
  final String source;

  bool get isTrainerRecommended => source == 'trainer';
  bool get isAiRecommended => source == 'ai';
}

/// Chat message viewpoint for the member: their own message vs the coach's.
enum CoachSender { me, trainer }

/// A message in the member↔coach thread — `/me/coach/chat`.
class CoachMessage {
  const CoachMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.timeLabel,
  });

  final String id;
  final CoachSender sender;
  final String body;
  final String timeLabel;

  bool get fromMe => sender == CoachSender.me;
}
