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
    this.completed = false,
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

  /// 회원이 이 배정을 이미 수행했는가. 서버가 `completed` 로 함께 내려준다.
  ///
  /// 취소는 **아직 하지 않은** 것만 물릴 수 있다 — 이미 한 운동을 배정 목록에서
  /// 지운다고 그 기록이 없던 일이 되지는 않으므로, 취소 버튼을 걸어 두면
  /// 트레이너가 기록까지 지운다고 오해한다(#1020).
  final bool completed;
}
