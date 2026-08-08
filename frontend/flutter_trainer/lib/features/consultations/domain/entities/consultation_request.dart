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
    required this.goalLabel,
    required this.purposeLabel,
    required this.preferredDate,
    required this.preferredTimeLabel,
    required this.status,
    this.message,
    this.purposeDetail,
    this.viaGym = false,
    this.gymName,
    this.decisionNote,
  });

  /// Server id — the path segment for accept / reject.
  final String id;

  /// The requesting member's user id.
  final String memberId;

  /// Display name. Falls back to a placeholder when the account is gone.
  final String memberName;

  /// 운동 목표, already localized (체중 감량 …).
  final String goalLabel;

  /// 건강관리 목적, already localized (만성질환 관리 …).
  final String purposeLabel;

  /// Free-text detail the member added to 건강관리 목적, if any.
  final String? purposeDetail;

  /// Requested date (`YYYY-MM-DD` parsed).
  final DateTime preferredDate;

  /// 희망 시간대, already localized (저녁 …).
  final String preferredTimeLabel;

  /// The member's own note to the trainer.
  final String? message;

  /// `pending` | `accepted` | `rejected`.
  final String status;

  /// Whether this came to the gym rather than to this trainer by name.
  ///
  /// A gym enquiry can be picked up by any trainer at that gym, so the
  /// card says so — otherwise the trainer cannot tell whether the member
  /// asked for them specifically.
  final bool viaGym;

  /// Gym name for a gym-routed request.
  final String? gymName;

  /// Rejection reason, once decided.
  final String? decisionNote;

  /// Whether this request is still waiting on a decision.
  bool get isPending => status == 'pending';
}
