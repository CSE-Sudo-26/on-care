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
    this.programName = '',
    this.sessionName = '',
    this.sessionOrder = 0,
    this.exercises = const <CoachRoutineExercise>[],
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

  /// 여러 세션으로 짜인 프로그램의 이름. 단일 루틴은 빈 문자열이다(#709).
  final String programName;

  /// 이 루틴이 그 프로그램의 어느 세션인가. 세션이 하나뿐이면 빈 문자열.
  final String sessionName;

  /// 프로그램 안에서의 세션 순서(0부터).
  final int sessionOrder;

  /// 이 세션에 담긴 운동 구성. 예전에는 이름만 [reason] 에 이어 붙어 왔다.
  final List<CoachRoutineExercise> exercises;

  /// 이 루틴이 여러 세션짜리 프로그램의 한 세션인가.
  bool get isProgramSession => sessionName.isNotEmpty;

  bool get isTrainerRecommended => source == 'trainer';
  bool get isAiRecommended => source == 'ai';

  CoachRoutine copyWith({
    bool? completed,
    DateTime? completedAt,
    int? completedMinutes,
    String? completedIntensity,
    String? memberNote,
    String? trainerFeedback,
  }) => CoachRoutine(
    id: id,
    name: name,
    minutes: minutes,
    type: type,
    reason: reason,
    source: source,
    completed: completed ?? this.completed,
    completedAt: completedAt ?? this.completedAt,
    completedMinutes: completedMinutes ?? this.completedMinutes,
    completedIntensity: completedIntensity ?? this.completedIntensity,
    memberNote: memberNote ?? this.memberNote,
    trainerFeedback: trainerFeedback ?? this.trainerFeedback,
    // 완료만 표시해도 프로그램·세션·운동 구성은 그대로 남아야 한다 — 빠뜨리면
    // 완료를 누른 순간 화면에서 프로그램 제목과 운동이 사라진다(#709).
    programName: programName,
    sessionName: sessionName,
    sessionOrder: sessionOrder,
    exercises: exercises,
  );
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

/// 배정된 세션 안의 운동 한 항목 — 트레이너 편집기가 적어 준 값 그대로다.
///
/// 세트·횟수·중량은 문자열이다. 트레이너가 "10회"·"자체중량" 처럼 적을 수 있고,
/// 숫자로 바꾸면 그 표현이 사라진다(#709).
class CoachRoutineExercise {
  const CoachRoutineExercise({
    required this.name,
    this.sets = '',
    this.reps = '',
    this.weight = '',
    this.duration = '',
    this.rest = '',
    this.memo = '',
  });

  final String name;
  final String sets;
  final String reps;
  final String weight;
  final String duration;
  final String rest;
  final String memo;

  /// "4세트 × 12회 · 60kg" 처럼 한 줄로 읽히는 요약. 비어 있는 값은 건너뛴다.
  String get detail => <String>[
    if (sets.isNotEmpty && reps.isNotEmpty)
      '$sets세트 × $reps'
    else if (sets.isNotEmpty)
      '$sets세트'
    else if (reps.isNotEmpty)
      reps,
    if (duration.isNotEmpty) '$duration분',
    if (weight.isNotEmpty && weight != '-') weight,
    if (rest.isNotEmpty) '휴식 $rest초',
  ].join(' · ');
}
