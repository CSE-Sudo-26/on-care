/// `CustomPaint` 로 그린 그래프를 스크린리더에 읽히게 하는 라벨 조립기. (#972)
///
/// `CustomPaint` 는 픽셀만 그리고 시맨틱 트리에는 아무 노드도 남기지 않는다.
/// 감싸는 위젯이 라벨을 주지 않으면 그 그래프는 음성 안내에서 **통째로 존재하지
/// 않는 영역**이 된다. 이 앱이 다루는 것이 혈압·혈당 위험군의 건강 지표라,
/// 숫자를 눈으로만 읽을 수 있게 두면 안 된다.
///
/// 두 앱은 패키지가 갈라져 있어 코드를 공유할 수 없다 — `metric_trend_chart`
/// 와 같은 방식으로 규칙을 양쪽에 같은 모양으로 둔다.
library;

import 'package:oncare/gen/l10n/app_localizations.dart';

/// 요일(또는 날짜) 한 칸을 `월 300kcal` 처럼 읽는 한 조각으로.
String chartPointLabel(AppLocalizations l, String day, String value) =>
    l.a11yChartPoint(day, value);

/// 그래프 하나를 한 문장으로. [points] 가 비면 비어 있다고 말한다 — 빈 그래프를
/// 말없이 두면 "값이 0" 인지 "아직 기록이 없는지"를 구분할 수 없다.
String chartSemanticsLabel(
  AppLocalizations l, {
  required String title,
  required List<String> points,
}) => points.isEmpty
    ? l.a11yChartEmpty(title)
    : l.a11yChartSummary(title, points.join(', '));

/// 값이 있는 날만 골라 [chartPointLabel] 조각으로 만든다.
///
/// 0 은 건너뛴다. 이 앱의 그래프에서 0 은 "그날 0 만큼 했다"가 아니라 **기록이
/// 없다**는 뜻이라(빈 트랙·회색 그루터기로 그린다), 0 을 읽어 주면 측정된 값처럼
/// 들린다. 하루도 남지 않으면 빈 목록이 되어 위 함수가 비어 있다고 말한다.
///
/// [upTo] 는 그래프가 실제로 그리는 마지막 칸이다. 이번 주 꺾은선은 오늘까지만
/// 잇는데, 아직 오지 않은 요일까지 읽으면 화면에 없는 값을 말하게 된다.
List<String> chartSeriesPoints(
  AppLocalizations l, {
  required List<double> values,
  required List<String> dayLabels,
  required String Function(double) format,
  int? upTo,
}) {
  final int last = upTo ?? values.length - 1;
  return <String>[
    for (int i = 0; i <= last && i < values.length && i < dayLabels.length; i++)
      if (values[i] != 0) chartPointLabel(l, dayLabels[i], format(values[i])),
  ];
}
