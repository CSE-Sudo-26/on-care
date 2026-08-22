/// One past workout in a client's history (운동기록 sub-tab). Decoded
/// from the drift `ClientRoutineHistory` row (`exercisesJson` becomes
/// the [exercises] list).
class RoutineHistoryEntry {
  /// Creates a history entry.
  const RoutineHistoryEntry({
    this.id = '',
    required this.dateLabel,
    this.date,
    required this.label,
    required this.completionRate,
    required this.exercises,
    required this.clientFeedback,
    required this.trainerNote,
    this.assignedRoutineId,
    this.completedAt,
  });

  /// Stable history id used when editing feedback.
  final String id;

  /// Display date (e.g. "7/12 (오늘)").
  final String dateLabel;

  /// 이 기록이 가리키는 날. [dateLabel] 은 사람이 읽는 표시용이라 날짜로 견줄
  /// 수 없어, 날짜별 기록에 이력을 붙이려면 이 값이 필요하다(#1025). 날짜를
  /// 알 수 없는 기록에서는 null 이다.
  final DateTime? date;

  /// Session kind (e.g. "PT 세션 · 트레이너 지도").
  final String label;

  /// 0–100 completion.
  final int completionRate;

  /// Exercise lines; a "✗" marks a skipped one (rendered struck-through).
  final List<String> exercises;

  /// Client's feedback (may be empty).
  final String clientFeedback;

  /// Trainer's note (may be empty — the note box is hidden then).
  final String trainerNote;

  /// Present only when this history row came from an assigned routine.
  final String? assignedRoutineId;
  final DateTime? completedAt;
}
