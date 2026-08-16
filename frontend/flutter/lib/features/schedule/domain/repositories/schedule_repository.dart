import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';

abstract class ScheduleRepository {
  /// Events whose `date` matches the given `YYYY-MM-DD` string.
  Future<List<ScheduleEvent>> fetchByDate(String date);

  /// Events in a `YYYY-MM` month (for the calendar month grid).
  Future<List<ScheduleEvent>> fetchByMonth(String month);

  /// POST /schedule/events — create a calendar event. The server derives
  /// the emoji/color from [category] and returns the stored event.
  Future<ScheduleEvent> createEvent({
    required String date,
    required String title,
    String time = '',
    ScheduleCategory category = ScheduleCategory.other,
  });

  /// PUT /schedule/events/{id} — 준 필드만 바꾼다.
  ///
  /// 넘기지 않은 항목은 서버가 그대로 둔다. 시간을 지우는 것은 `''` 를 넘기는
  /// 것이지 생략이 아니다 — 생략은 "안 바꿈" 이다.
  Future<ScheduleEvent> updateEvent(
    String id, {
    String? date,
    String? time,
    String? title,
    ScheduleCategory? category,
  });

  /// DELETE /schedule/events/{id}.
  ///
  /// 되돌릴 수 없다. 부르기 전에 사용자 확인을 받는 것은 화면의 몫이다.
  Future<void> deleteEvent(String id);
}
