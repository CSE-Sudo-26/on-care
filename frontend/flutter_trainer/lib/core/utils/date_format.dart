import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Formats [d] as the `YYYY-MM-DD` string used by every date-keyed
/// drift column (seeding, schedule filters, reservation counts). Single
/// source of truth so writers and readers can never drift apart.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Weekday names indexed by `DateTime.weekday - 1` (월 … 일), in the
/// current locale.
List<String> weekdayNames(AppLocalizations l) => <String>[
  l.weekdayMon,
  l.weekdayTue,
  l.weekdayWed,
  l.weekdayThu,
  l.weekdayFri,
  l.weekdaySat,
  l.weekdaySun,
];

/// Human date for page headers — `8월 5일 (화)` / `8/5 (Tue)`, with
/// `오늘`/`내일` prefixed when [relativeTo] (defaults to now) makes that
/// clearer.
///
/// 로케일을 인자로 받는다 — 순수 함수라 컨텍스트를 가질 수 없고, 호출부가
/// 어느 언어로 그리는지 명시하는 편이 읽기도 쉽다. (#501)
String dateLabel(AppLocalizations l, DateTime d, {DateTime? relativeTo}) {
  final base = relativeTo ?? DateTime.now();
  final today = DateTime(base.year, base.month, base.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = target.difference(today).inDays;
  final prefix = switch (diff) {
    0 => l.dateToday,
    1 => l.dateTomorrow,
    -1 => l.dateYesterday,
    _ => '',
  };
  final date = l.dateMonthDayWeekday(
    d.month,
    d.day,
    weekdayNames(l)[d.weekday - 1],
  );
  return prefix.isEmpty ? date : l.datePrefixed(prefix, date);
}
