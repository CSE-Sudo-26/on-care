/// One bookable time on a trainer's calendar.
///
/// Slots belong to a trainer, not to a gym: a gym employs several trainers and
/// each keeps their own hours, so the same gym shows different times depending
/// on who you are booking.
///
/// 자리는 언제나 한 사람 몫이다 — 트레이너는 1:1 PT 만 진행한다. 그래서 정원과
/// 잔여 인원 개념이 없고, 슬롯은 **비었거나 예약된** 두 상태뿐이다(#1072).
class TrainerSlot {
  const TrainerSlot({
    required this.id,
    required this.trainerId,
    required this.startsAt,
    required this.booked,
  });

  final String id;
  final String trainerId;

  /// When the session starts. Rendered with the device locale rather than a
  /// fixed "오늘/내일" string, so the label stays true as days pass.
  final DateTime startsAt;

  /// 이미 예약된 자리인가. 예약된 자리도 숨기지 않고 비활성으로 남겨, 그
  /// 트레이너의 하루가 "비어 있음" 이 아니라 "찼음" 으로 읽히게 한다.
  final bool booked;

  TrainerSlot copyWith({bool? booked}) {
    return TrainerSlot(
      id: id,
      trainerId: trainerId,
      startsAt: startsAt,
      booked: booked ?? this.booked,
    );
  }
}
