/// One member's consultation request as the trainer sees it.
///
/// The member app writes these (`POST /consultations`); until a trainer
/// accepts one there is no trainer↔member link, so this is the only place
/// a real roster can start. Accepting is what creates the link — the demo
/// roster comes from seed data instead.
class ConsultationRequest {
  /// Creates a request card.
  const ConsultationRequest({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.goalCode,
    required this.purposeCode,
    required this.preferredDate,
    required this.preferredTimeCode,
    required this.status,
    this.message,
    this.purposeDetail,
    this.decisionNote,
  });

  /// Server id — the path segment for accept / reject.
  final String id;

  /// The requesting member's user id.
  final String memberId;

  /// Display name. Falls back to a placeholder when the account is gone.
  final String memberName;

  /// 운동 목표, already localized (체중 감량 …).
  /// 서버 enum 코드('weight_loss' …). 화면 문구는 [exerciseGoalLabels] 로 만든다.
  final String goalCode;

  /// 건강관리 목적, already localized (만성질환 관리 …).
  /// 서버 enum 코드('chronic' …). 화면 문구는 [healthPurposeLabels] 로 만든다.
  final String purposeCode;

  /// Free-text detail the member added to 건강관리 목적, if any.
  final String? purposeDetail;

  /// Requested date (`YYYY-MM-DD` parsed).
  final DateTime preferredDate;

  /// 희망 시간대, already localized (저녁 …).
  /// 서버 enum 코드('morning' …). 화면 문구는 [preferredTimeLabels] 로 만든다.
  final String preferredTimeCode;

  /// The member's own note to the trainer.
  final String? message;

  /// `pending` | `accepted` | `rejected`.
  final String status;

  /// Rejection reason, once decided.
  final String? decisionNote;

  /// Whether this request is still waiting on a decision.
  bool get isPending => status == 'pending';
}
