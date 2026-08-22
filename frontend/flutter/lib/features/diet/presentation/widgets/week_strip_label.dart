import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:oncare/gen/l10n/app_localizations.dart';

/// 주간 달력 위에 적는 한 줄 — 고른 날이 오늘이면 `오늘`, 아니면 그 날짜.
///
/// 예전에는 `n월 n주차` 였다. 주차 번호는 세는 방법에 따라 달라져, 어느 날을
/// 보고 있는지 오히려 흐렸다. 지금 고른 날을 그대로 적는다. (#1059)
String weekStripLabel(
  BuildContext context,
  AppLocalizations l, {
  required DateTime selected,
  required DateTime today,
}) {
  if (selected.year == today.year &&
      selected.month == today.month &&
      selected.day == today.day) {
    return l.exToday;
  }
  return DateFormat.yMMMMd(
    Localizations.localeOf(context).toString(),
  ).format(selected);
}
