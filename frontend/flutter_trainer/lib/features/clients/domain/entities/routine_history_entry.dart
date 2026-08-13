/// One past workout in a client's history (운동기록 sub-tab). Decoded
/// from the drift `ClientRoutineHistory` row (`exercisesJson` becomes
/// the [exercises] list).
class RoutineHistoryEntry {
  /// Creates a history entry.
  const RoutineHistoryEntry({
    this.id = '',
    required this.dateLabel,
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
