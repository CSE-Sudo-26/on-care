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
    this.completed = false,
    this.completedAt,
    this.completedMinutes,
    this.completedIntensity,
    this.memberNote = '',
    this.trainerFeedback = '',
  });

  final String id;
  final String name;
  final int minutes;
  final String type;
  final String reason;

  /// `ai` (AI-suggested) or `trainer` (hand-assigned).
  final String source;
  final bool completed;
  final DateTime? completedAt;
  final int? completedMinutes;
  final String? completedIntensity;
  final String memberNote;
  final String trainerFeedback;

  bool get isTrainerRecommended => source == 'trainer';
  bool get isAiRecommended => source == 'ai';
}

/// A PT session the coach booked for the member — `/me/coach/sessions`.
///
/// The trainer owns the schedule: the member can see it but not change it, so
/// this carries no edit affordance. (#490)
class CoachSession {
  /// Creates a booked session.
  const CoachSession({
    required this.id,
    required this.date,
    required this.time,
    required this.type,
    required this.durationMinutes,
    required this.status,
    this.note = '',
    this.program = const <CoachProgramItem>[],
  });

  /// Server id.
  final String id;

  /// `YYYY-MM-DD` parsed. Unparseable dates keep the session out of the
  /// screen rather than throwing — one bad row must not blank the list.
  final DateTime? date;

  /// `HH:MM` as the server sent it.
  final String time;

  /// 1:1 PT · 그룹 · 상담 …
  final String type;

  /// Session length.
  final int durationMinutes;

  /// 예정 | 완료 | 공백.
  final String status;

  /// The trainer's feedback recorded when completing the session.
  final String note;

  /// The workout program attached by the trainer.
  final List<CoachProgramItem> program;

  /// Whether this session is still ahead. 완료된 세션은 '오늘의 일정'에
  /// 남겨 둘 이유가 없다.
  bool get isUpcoming => status != '완료';

  /// Whether the trainer has completed this session.
  bool get isDone => status == '완료';
}

/// One exercise in a trainer-authored PT program.
class CoachProgramItem {
  const CoachProgramItem({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  final String name;
  final int sets;
  final String reps;
  final String weight;
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
    required this.createdAt,
  });

  final String id;
  final CoachSender sender;
  final String body;
  final String timeLabel;
  final DateTime createdAt;

  bool get fromMe => sender == CoachSender.me;
}
