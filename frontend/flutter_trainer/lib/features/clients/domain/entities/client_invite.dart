/// 이메일 완전 일치로 찾은 회원 한 명.
///
/// 요청을 보낼지 판단할 만큼만 담는다 — 이름, 이미 담당이 있는지, 내가 보낸
/// 요청이 기다리고 있는지. 담당이 **누구인지**는 서버도 알려 주지 않는다.
/// 담당이 아닌 트레이너가 알 이유가 없는 값이다. (#919)
class MemberLookup {
  const MemberLookup({
    required this.memberId,
    required this.name,
    required this.email,
    required this.hasTrainer,
    required this.coachedByMe,
    required this.invitePending,
  });

  final String memberId;
  final String name;
  final String email;

  /// 이미 활성 담당 트레이너가 있는가.
  final bool hasTrainer;

  /// 그 담당이 나인가 — 이미 명단에 있는 회원을 다시 찾은 경우.
  final bool coachedByMe;

  /// 내가 보낸 요청이 대기 중인가.
  final bool invitePending;

  /// 지금 이 회원에게 요청을 보낼 수 있는가.
  bool get canInvite => !hasTrainer && !invitePending;

  factory MemberLookup.fromJson(Map<String, Object?> json) => MemberLookup(
    memberId: json['member_id']! as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    hasTrainer: json['has_trainer'] as bool? ?? false,
    coachedByMe: json['coached_by_me'] as bool? ?? false,
    invitePending: json['invite_pending'] as bool? ?? false,
  );
}

/// 담당 요청의 처리 상태.
enum ClientInviteStatus {
  pending,
  accepted,
  rejected,
  cancelled;

  static ClientInviteStatus parse(Object? value) => switch (value) {
    'accepted' => ClientInviteStatus.accepted,
    'rejected' => ClientInviteStatus.rejected,
    'cancelled' => ClientInviteStatus.cancelled,
    _ => ClientInviteStatus.pending,
  };
}

/// 트레이너가 회원에게 보낸 담당 요청.
///
/// 이것이 있다고 해서 명단에 회원이 생기지는 않는다 — 담당은 회원이 수락해야
/// 생긴다. 그래서 이 목록은 고객 목록과 나란히 있지 않고, 등록 시트 안에서만
/// 보인다. 두 목록을 섞으면 "요청 = 고객" 으로 읽힌다.
class ClientInvite {
  const ClientInvite({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.memberEmail,
    required this.status,
    required this.createdAt,
    this.message,
  });

  final String id;
  final String memberId;
  final String memberName;
  final String memberEmail;
  final ClientInviteStatus status;
  final DateTime createdAt;
  final String? message;

  bool get isPending => status == ClientInviteStatus.pending;

  factory ClientInvite.fromJson(Map<String, Object?> json) => ClientInvite(
    id: json['id']! as String,
    memberId: json['member_id'] as String? ?? '',
    memberName: json['member_name'] as String? ?? '',
    memberEmail: json['member_email'] as String? ?? '',
    status: ClientInviteStatus.parse(json['status']),
    // 보낸 시각이 없거나 깨졌으면 조용히 '지금' 으로 메우지 않는다 — 언제
    // 보냈는지가 트레이너가 기다릴지 다시 보낼지를 정하는 값이라, 틀린 값보다
    // 실패가 낫다(다른 응답 파서와 같은 규약).
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        (throw const FormatException('Invalid client invite created_at.')),
    message: json['message'] as String?,
  );
}
