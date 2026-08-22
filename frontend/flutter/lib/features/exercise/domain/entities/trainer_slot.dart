/// One bookable time on a trainer's calendar.
///
/// Slots belong to a trainer, not to a gym: a gym employs several trainers and
/// each keeps their own hours, so the same gym shows different times depending
/// on who you are booking.
class TrainerSlot {
  const TrainerSlot({
    required this.id,
    required this.trainerId,
    required this.startsAt,
    required this.capacity,
    required this.remaining,
    required this.sessionType,
  });

  final String id;
  final String trainerId;

  /// When the session starts. Rendered with the device locale rather than a
  /// fixed "오늘/내일" string, so the label stays true as days pass.
  final DateTime startsAt;

  /// How many people the slot takes in total.
  final int capacity;

  /// Places still open. 0 means booked out — the chip is shown but not
  /// selectable, so the trainer's day still reads as full rather than empty.
  final int remaining;

  /// `'1:1 PT'` 또는 `'상담'` — 트레이너 앱 스케줄 탭의 세션 종류와 같은
  /// 계약값이다. 회원이 이 시간을 예약하면 만들어지는 일정이 이 종류를
  /// 그대로 물려받는다.
  final String sessionType;

  bool get isFull => remaining <= 0;

  TrainerSlot copyWith({int? remaining}) {
    return TrainerSlot(
      id: id,
      trainerId: trainerId,
      startsAt: startsAt,
      capacity: capacity,
      remaining: remaining ?? this.remaining,
      sessionType: sessionType,
    );
  }
}
