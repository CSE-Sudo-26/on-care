/// Formats [d] as the `YYYY-MM-DD` string used by every date-keyed
/// drift column (seeding, schedule filters, reservation counts). Single
/// source of truth so writers and readers can never drift apart.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Korean weekday names indexed by `DateTime.weekday - 1` (월 … 일).
const List<String> koreanWeekdays = <String>['월', '화', '수', '목', '금', '토', '일'];

/// Human date for page headers — `8월 5일 (화)`, with `오늘`/`내일`
/// prefixed when [relativeTo] (defaults to now) makes that clearer.
String koreanDateLabel(DateTime d, {DateTime? relativeTo}) {
  final base = relativeTo ?? DateTime.now();
  final today = DateTime(base.year, base.month, base.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = target.difference(today).inDays;
  final prefix = switch (diff) {
    0 => '오늘 · ',
    1 => '내일 · ',
    -1 => '어제 · ',
    _ => '',
  };
  return '$prefix${d.month}월 ${d.day}일 (${koreanWeekdays[d.weekday - 1]})';
}
