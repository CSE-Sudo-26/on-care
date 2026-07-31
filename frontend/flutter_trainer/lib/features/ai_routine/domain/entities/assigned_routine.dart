/// A routine assigned to a member (the `RoutineOut` shape shared with the
/// member app's `/me/coach/routines`). Sending one from the trainer app is
/// how a member receives a routine.
class AssignedRoutine {
  const AssignedRoutine({
    required this.id,
    required this.name,
    required this.minutes,
    required this.type,
    required this.reason,
    required this.source,
  });

  /// Server id (empty before assignment).
  final String id;

  /// Routine label (e.g. "AI 맞춤 루틴").
  final String name;

  /// Total minutes.
  final int minutes;

  /// One of 유산소 | 근력 | 스트레칭.
  final String type;

  /// Why this routine — surfaced to the member.
  final String reason;

  /// `ai` (AI-suggested) or `trainer` (hand-assigned).
  final String source;
}
