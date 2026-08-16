/// 일정 계약 형식 — 날짜 `YYYY-MM-DD`, 시간 `HH:mm`(또는 빈 문자열).
///
/// 검사를 한곳에 모아 두는 이유: 이 형식은 저장할 때만 쓰는 것이 아니라
/// **조회할 때 전제**가 된다. 달 조회는 `YYYY-MM-` 로 시작하는지 보고, 캘린더는
/// 날짜의 마지막 조각을 숫자로 읽는다. 그래서 형식을 벗어난 값이 한 번 저장되면
/// 그 일정은 어디에도 나타나지 않는다(#785).
///
/// FastAPI 쪽 같은 검사는 `backend/app/api/v1/schedule.py` 에 있다. 두 곳이
/// 갈리면 데모와 실서버가 다르게 답하므로 규칙을 함께 유지한다.
library;

final RegExp _ymd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _hhmm = RegExp(r'^\d{2}:\d{2}$');

/// `YYYY-MM-DD` 이면서 달력상 실제로 있는 날인지.
///
/// 형식만 보면 `2026-02-30`·`2026-13-01` 이 통과한다. `DateTime.parse` 는 월·일
/// 범위를 넘긴 값을 다음 달로 굴려 버리므로(2026-02-30 → 3월 2일), 파싱한 결과가
/// 넣은 값과 같은지까지 확인해야 한다.
bool isScheduleDate(String value) {
  if (!_ymd.hasMatch(value)) return false;
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  return parsed.year == int.parse(value.substring(0, 4)) &&
      parsed.month == int.parse(value.substring(5, 7)) &&
      parsed.day == int.parse(value.substring(8, 10));
}

/// `HH:mm`(24시간) 이거나 빈 문자열인지. 시간은 선택 항목이라 빈 값을 허용한다.
bool isScheduleTime(String value) {
  if (value.isEmpty) return true;
  if (!_hhmm.hasMatch(value)) return false;
  final int hour = int.parse(value.substring(0, 2));
  final int minute = int.parse(value.substring(3, 5));
  return hour < 24 && minute < 60;
}
