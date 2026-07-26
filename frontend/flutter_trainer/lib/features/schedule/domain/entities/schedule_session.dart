/// One exercise in a PT session's program (e.g. 레그프레스 3세트 × 12회 · 80kg).
class ProgramItem {
  /// Creates a program item.
  const ProgramItem({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  /// Exercise name.
  final String name;

  /// Set count.
  final int sets;

  /// Reps label (e.g. "12회", "10분", "45초").
  final String reps;

  /// Weight label (e.g. "80kg", "자체중량", "-" for none).
  final String weight;
}

/// One slot on the trainer's daily timeline (스케줄 탭). Decoded from
/// the drift `TrainerScheduleEntries` row (`programJson` → [program]).
class ScheduleSession {
  /// Creates a schedule slot.
  const ScheduleSession({
    required this.id,
    required this.time,
    required this.clientName,
    required this.type,
    required this.durationMinutes,
    required this.status,
    required this.note,
    required this.program,
  });

  /// Row id.
  final String id;

  /// Slot time (e.g. "10:00").
  final String time;

  /// Booked client's name — empty for a gap slot.
  final String clientName;

  /// Session kind (e.g. "1:1 PT", "상담") — empty for a gap.
  final String type;

  /// Duration in minutes (0 for a gap).
  final int durationMinutes;

  /// 완료 | 예정 | 공백.
  final String status;

  /// Trainer's note for the session (may be empty).
  final String note;

  /// The session's exercise program (empty when none).
  final List<ProgramItem> program;

  /// Whether this is an empty ("빈 시간") slot.
  bool get isGap => status == '공백';

  /// Whether the session is done.
  bool get isDone => status == '완료';

  /// Whether the session is still upcoming (예정).
  bool get isUpcoming => status == '예정';

  /// Whether the card can expand. Every booked session opens: 완료 shows
  /// the finished program, 예정 shows the plan (or a no-plan hint), and
  /// both expose the manage/chat actions.
  bool get expandable => !isGap;
}
