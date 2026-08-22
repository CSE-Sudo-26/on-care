/// A reservable time exposed by a trainer — 1:1 PT or 상담.
class ReservationSlot {
  const ReservationSlot({
    required this.id,
    required this.startsAt,
    required this.capacity,
    required this.remaining,
    required this.isClosed,
    required this.sessionType,
  });

  final String id;
  final DateTime startsAt;
  final int capacity;
  final int remaining;
  final bool isClosed;

  /// `SessionType.personalTraining`(`1:1 PT`) 또는 `SessionType.consultation`
  /// (`상담`) — 스케줄 탭의 세션 종류와 같은 계약값이다(#1083).
  final String sessionType;

  int get booked => capacity - remaining;

  factory ReservationSlot.fromJson(Map<String, dynamic> json) {
    return ReservationSlot(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      capacity: json['capacity'] as int,
      remaining: json['remaining'] as int,
      isClosed: json['is_closed'] as bool? ?? false,
      sessionType: json['session_type'] as String? ?? '1:1 PT',
    );
  }
}
