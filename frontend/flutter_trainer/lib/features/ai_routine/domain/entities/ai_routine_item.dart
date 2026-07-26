/// One AI-suggested routine item for a client (AI 루틴 탭). Decoded from
/// the drift `ClientAiRoutines` row.
class AiRoutineItem {
  /// Creates a routine item.
  const AiRoutineItem({
    required this.id,
    required this.name,
    required this.minutes,
    required this.type,
    required this.reason,
  });

  /// Row id (used to key per-item edits).
  final String id;

  /// Exercise name (e.g. "저강도 유산소 (걷기)").
  final String name;

  /// Suggested duration in minutes.
  final int minutes;

  /// 유산소 | 근력 | 스트레칭.
  final String type;

  /// Why the AI suggests it (e.g. "혈압 안정에 효과적").
  final String reason;
}
