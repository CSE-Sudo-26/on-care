/// A reservable PT time exposed by a trainer.
class ReservationSlot {
  const ReservationSlot({
    required this.id,
    required this.startsAt,
    required this.capacity,
    required this.remaining,
    required this.isClosed,
  });

  final String id;
  final DateTime startsAt;
  final int capacity;
  final int remaining;
  final bool isClosed;

  int get booked => capacity - remaining;

  factory ReservationSlot.fromJson(Map<String, dynamic> json) {
    return ReservationSlot(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      capacity: json['capacity'] as int,
      remaining: json['remaining'] as int,
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }
}
