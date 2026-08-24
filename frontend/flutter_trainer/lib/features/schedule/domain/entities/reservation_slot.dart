/// A reservable time exposed by a trainer — 1:1 PT or 상담.
///
/// 자리는 언제나 한 사람 몫이다 — 1:1 PT 든 상담이든 여럿이 함께 듣지 않는다.
/// 그래서 정원과 잔여 인원 개념이 없고, 자리는 **비었거나 예약된** 두 상태뿐이다
/// (#1072).
class ReservationSlot {
  const ReservationSlot({
    required this.id,
    required this.startsAt,
    this.durationMinutes = 60,
    required this.booked,
    required this.isClosed,
    required this.sessionType,
  });

  final String id;
  final DateTime startsAt;
  final int durationMinutes;

  /// 회원이 이미 잡아 간 자리인가.
  final bool booked;

  final bool isClosed;

  /// `SessionType.personalTraining`(`1:1 PT`) 또는 `SessionType.consultation`
  /// (`상담`) — 스케줄 탭의 세션 종류와 같은 계약값이다(#1083).
  final String sessionType;

  factory ReservationSlot.fromJson(Map<String, dynamic> json) {
    return ReservationSlot(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      // 서버는 아직 좌석 수로 자리를 센다. 한 사람 몫뿐인 자리라 남은 좌석이
      // 0인지만 의미가 있으므로 여기서 예약 여부로 접는다(#1072).
      booked: ((json['remaining'] as num?) ?? 0).toInt() <= 0,
      isClosed: json['is_closed'] as bool? ?? false,
      sessionType: json['session_type'] as String? ?? '1:1 PT',
    );
  }
}
