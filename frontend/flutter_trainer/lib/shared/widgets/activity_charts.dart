/// 운동 유형별 그림 — 회원 앱 운동 탭 `운동 현황` 과 **같은 그림**이다. (#943)
///
/// 회원 앱 `features/exercise/presentation/pages/exercise_page.dart` 의 도넛과
/// 누적 막대를 트레이너 콘솔 토큰으로 옮긴 것이다. 두 앱은 패키지가 갈라져 있어
/// 코드를 공유할 수 없으므로, 규칙을 여기에도 적어 둔다 — `metric_trend_chart`
/// 를 옮겨 둔 것과 같은 방식이다. 한쪽만 고치면 회원이 보는 그래프와 트레이너가
/// 보는 그래프가 다른 이야기를 한다.
///
///  * 유형 순서는 언제나 유산소 → 근력 → 스트레칭이다. 도넛도 막대도 범례도
///    같은 순서라, 색을 외우지 않아도 자리로 읽힌다.
///  * 막대는 아래에서부터 스트레칭 → 근력 → 유산소로 쌓는다. **맨 위 구간만**
///    모서리를 둥글려, 어떤 유형이 위에 오든 막대의 머리 모양이 같다.
///  * 기록이 없는 날은 3px 짜리 회색 그루터기다. 0 을 아예 안 그리면 그날이
///    빠진 것처럼 보이고, 색을 주면 짧은 운동을 한 것처럼 보인다.
///
/// 회원 앱에는 막대가 자라 오르는 진입 애니메이션이 있지만 여기서는 정적으로
/// 그린다. 트레이너 콘솔의 다른 차트(`BarSeriesChart`)도 정적이라, 한 화면에서
/// 어떤 그래프는 자라고 어떤 그래프는 이미 서 있으면 그게 더 튄다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/chart_semantics.dart';
import 'package:oncare_trainer/shared/widgets/goal_line.dart';
import 'package:oncare_trainer/shared/widgets/period_scroll_chart.dart';

/// 도넛 한 조각 / 범례 한 줄.
class ActivitySeg {
  /// Creates a segment.
  const ActivitySeg(this.label, this.minutes, this.color);

  final String label;
  final int minutes;
  final Color color;
}

/// 하루치 유형별 활동 분. 막대 하나가 이 값을 쌓아 그린다.
class ActivityBar {
  /// Creates one day's split.
  const ActivityBar(this.cardio, this.strength, this.stretch);

  final double cardio;
  final double strength;
  final double stretch;

  double get total => cardio + strength + stretch;
}

/// `오늘` 뷰: 왼쪽 도넛(유형 비중) + 오른쪽 유형별 시간.
class ActivityDonut extends StatelessWidget {
  /// Creates the donut for [segs].
  const ActivityDonut({super.key, required this.segs, required this.title});

  final List<ActivitySeg> segs;

  /// 오른쪽 열 머리글 — `오늘 총 운동 시간`.
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int total = segs.fold<int>(
      0,
      (int a, ActivitySeg s) => a + s.minutes,
    );
    return SizedBox(
      height: 170,
      // 좁은 화면에서 고정폭 도넛 + 범례가 넘치지 않도록 통째로 줄인다. 넓을
      // 때는 가운데 정렬된 지금 배치 그대로다.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 116,
              height: 116,
              // 도넛은 `CustomPaint` 라 시맨틱 트리에 아무 노드도 남기지 않고,
              // 가운데 숫자는 `45` 와 `분` 두 조각으로 흩어져 읽힌다. 한
              // 덩어리로 묶어 무엇의 몇 분인지 한 문장으로 말한다(#972).
              // 유형별 내역은 오른쪽 범례가 이어서 읽어 준다.
              child: Semantics(
                container: true,
                label: chartSemanticsLabel(
                  l,
                  title: title,
                  points: total == 0
                      ? const <String>[]
                      : <String>[l.minutesShort(total)],
                ),
                child: ExcludeSemantics(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: const Size.square(116),
                        painter: _DonutPainter(segs),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '$total',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                              height: 1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            l.unitMinutes,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
            SizedBox(
              width: 180,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.subtleForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ActivitySeg s in segs) ...<Widget>[
                    _DonutLegendRow(seg: s),
                    if (s != segs.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({required this.seg});

  final ActivitySeg seg;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: seg.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        // 범례 열은 폭이 고정이라, 큰 글자 배율에서 라벨과 분 수가 나란히 서면
        // 그 폭을 넘긴다. 둘 다 줄어들 수 있게 두고 한 줄로 자른다.
        Expanded(
          child: Text(
            seg.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
        ),
        Flexible(
          child: Text(
            l.minutesShort(seg.minutes),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.segs);

  final List<ActivitySeg> segs;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = segs.fold<double>(
      0,
      (double a, ActivitySeg s) => a + s.minutes,
    );
    if (total <= 0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double stroke = 20;
    final double radius = (size.width - stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double gap = 0.06; // 조각 사이 간격(라디안)
    const double full = 2 * math.pi;
    double start = -math.pi / 2; // 12시 방향
    for (final ActivitySeg s in segs) {
      final double share = (s.minutes / total) * full;
      final double sweep = share - gap;
      // 0분짜리 유형은 건너뛴다 — 음수 sweep 은 둥근 끝 때문에 점 하나로 남는다.
      if (s.minutes <= 0 || sweep <= 0) {
        start += share;
        continue;
      }
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = s.color,
      );
      start += share;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segs != segs;
}

/// `이번 주`·`이번 달` 뷰: 유형별 3색 누적 막대 + 범례.
class ActivityBarChart extends StatelessWidget {
  /// Creates the chart.
  const ActivityBarChart({
    super.key,
    required this.bars,
    required this.dayLabels,
    required this.todayIndex,
    required this.title,
    this.dailyGoalMinutes = 0,
    this.selection,
    this.dates,
  });

  final List<ActivityBar> bars;
  final List<String> dayLabels;

  /// 하루 목표 운동 시간(분). 0 이면 목표선을 그리지 않는다. 가로선은 이
  /// 목표선 하나뿐이다 — 눈금선은 지웠다. (#1015)
  final double dailyGoalMinutes;

  /// 있으면 `전체` 모양 — 옆으로 밀어 보고 한 칸을 고를 수 있다. 없으면 이번
  /// 주 모양(일곱 칸이 한 화면)이다. (#1018)
  final PeriodChartSelection? selection;

  /// 칸마다의 날짜. `전체` 에서 축 라벨과 고른 날 표시에 쓴다.
  final List<DateTime>? dates;

  /// 그래프가 무엇을 그린 것인지 — 기록이 하나도 없는 기간에 비어 있다고
  /// 말할 때 이 이름으로 부른다(#972).
  final String title;

  /// 오늘에 해당하는 칸. 범위 밖이면 -1.
  final int todayIndex;

  /// 툴팁과 **같은 내용**을 시맨틱 라벨로. 색 사각형(`WidgetSpan`)은 빼고
  /// 줄바꿈은 쉼표로 바꾼다 — 음성 안내는 줄을 나누어 읽지 않는다. 어느 날의
  /// 막대인지 먼저 말해야 하므로 요일을 앞에 붙인다(#972).
  String _barSemantics(AppLocalizations l, int i) => chartPointLabel(
    l,
    dayLabels[i],
    TextSpan(children: _tipSpans(l, i))
        .toPlainText(includePlaceholders: false)
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .join(', '),
  );

  /// 막대 하나의 툴팁 — `[색] 유형   N분` 을 줄마다.
  List<InlineSpan> _tipSpans(AppLocalizations l, int i) {
    final ActivityBar b = bars[i];
    final List<(Color, String, int)> rows = <(Color, String, int)>[
      if (b.cardio > 0)
        (AppColors.chartCardio, l.routineTypeCardio, b.cardio.round()),
      if (b.strength > 0)
        (AppColors.chartStrength, l.routineTypeStrength, b.strength.round()),
      if (b.stretch > 0)
        (AppColors.chartStretching, l.routineTypeStretching, b.stretch.round()),
    ];
    if (rows.isEmpty) return <InlineSpan>[TextSpan(text: l.chartNoRecord)];
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int k = 0; k < rows.length; k++) {
      final (Color color, String label, int minutes) = rows[k];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
      spans.add(TextSpan(text: '$label   ${l.minutesShort(minutes)}'));
      if (k < rows.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 한 칸도 기록이 없는 기간은 막대마다 `기록 없음` 을 서른 번 읽히는 대신
    // 비어 있다고 한 번만 말한다(#972).
    final bool empty = bars.every((ActivityBar b) => b.total <= 0);
    final PeriodChartSelection? selection = this.selection;
    if (selection != null) {
      // `전체` — 12주치를 옆으로 밀어 본다. 한 화면에 30일. (#1018)
      return Semantics(
        container: true,
        label: empty
            ? chartSemanticsLabel(l, title: title, points: const <String>[])
            : null,
        child: ExcludeSemantics(
          excluding: empty,
          child: _ScrollingBars(
            bars: bars,
            dates: dates ?? const <DateTime>[],
            dailyGoalMinutes: dailyGoalMinutes,
            selection: selection,
            tipSpans: (int i) => _tipSpans(l, i),
            goalLabel:
                '${l.clientPeriodGoal} '
                '${dailyGoalMinutes.round()}${l.unitMinutes}',
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      label: empty
          ? chartSemanticsLabel(l, title: title, points: const <String>[])
          : null,
      child: ExcludeSemantics(
        excluding: empty,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StackedBarPainter(
                        bars: bars,
                        dayLabels: dayLabels,
                        todayIndex: todayIndex,
                        todayLabel: l.labelToday,
                        goal: dailyGoalMinutes,
                        goalLabel:
                            '${l.clientPeriodGoal} '
                            '${dailyGoalMinutes.round()}${l.unitMinutes}',
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                  // 막대 위에 겹치는 투명한 hover 영역. painter 의 칸과 자리를
                  // 맞춘다(왼쪽 눈금 24, 아래 라벨 24).
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, bottom: 24),
                      child: Row(
                        children: <Widget>[
                          for (int i = 0; i < bars.length; i++)
                            Expanded(
                              child: Semantics(
                                label: _barSemantics(l, i),
                                child: Tooltip(
                                  key: Key('activity-bar-$i'),
                                  richMessage: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.foreground,
                                      height: 1.15,
                                    ),
                                    children: _tipSpans(l, i),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.inputBackground,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.borderStrong,
                                    ),
                                    boxShadow: kCardShadow,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 범례 셋은 좁아지면 다음 줄로 넘긴다. 한 줄에 붙여 두면 라벨을 줄여야
            // 하고, 그러면 무슨 색이 무엇인지가 사라진다.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                ActivityLegend(
                  color: AppColors.chartCardio,
                  label: l.routineTypeCardio,
                ),
                ActivityLegend(
                  color: AppColors.chartStrength,
                  label: l.routineTypeStrength,
                ),
                ActivityLegend(
                  color: AppColors.chartStretching,
                  label: l.routineTypeStretching,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 범례 한 칸 — 색 사각형 + 유형 이름.
class ActivityLegend extends StatelessWidget {
  /// Creates one legend entry.
  const ActivityLegend({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(AppRadius.xs),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedForeground,
        ),
      ),
    ],
  );
}

/// `전체` 모양의 막대 — 스크롤 안에서 칸마다 위젯으로 그린다. 주간 막대를
/// 그리는 [_StackedBarPainter] 와 **같은 색·같은 순서**다. (#1018)
class _ScrollingBars extends StatelessWidget {
  const _ScrollingBars({
    required this.bars,
    required this.dates,
    required this.dailyGoalMinutes,
    required this.selection,
    required this.tipSpans,
    required this.goalLabel,
  });

  final List<ActivityBar> bars;
  final List<DateTime> dates;
  final double dailyGoalMinutes;
  final PeriodChartSelection selection;
  final List<InlineSpan> Function(int i) tipSpans;
  final String goalLabel;

  @override
  Widget build(BuildContext context) {
    const double chartHeight = 150;
    final double peak = <double>[
      dailyGoalMinutes,
      for (final ActivityBar b in bars) b.total,
    ].fold<double>(1, (double a, double b) => math.max(a, b));
    final double max = peak * 1.15;
    final int labelStep = (bars.length / 12).ceil().clamp(1, 7);

    return ListenableBuilder(
      listenable: selection,
      builder: (BuildContext context, Widget? _) => PeriodScrollChart(
        count: bars.length,
        height: chartHeight,
        selectedIndex: selection.selected,
        onSelected: selection.select,
        onVisibleRangeChanged: selection.setVisible,
        goalOverlay: GoalLineOverlay(
          visible: dailyGoalMinutes > 0,
          bottom: chartHeight * (dailyGoalMinutes / max).clamp(0.0, 1.0),
          label: goalLabel,
        ),
        labelBuilder: (int i) => i < dates.length && i % labelStep == 0
            ? '${dates[i].day}'
            : '',
        calloutBuilder: (BuildContext context, int i) =>
            const SizedBox.shrink(),
        barBuilder: (BuildContext context, int i) => Tooltip(
          key: Key('client-exercise-bar-$i'),
          richMessage: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
              height: 1.35,
            ),
            children: tipSpans(i),
          ),
          child: _ActivityBarColumn(
            bar: bars[i],
            max: max,
            height: chartHeight,
            dimmed: selection.selected != null && selection.selected != i,
          ),
        ),
      ),
    );
  }
}

/// 한 칸 — 유연성(연) → 근력(진) → 유산소(브랜드) 순으로 아래에서 쌓는다.
class _ActivityBarColumn extends StatelessWidget {
  const _ActivityBarColumn({
    required this.bar,
    required this.max,
    required this.height,
    required this.dimmed,
  });

  final ActivityBar bar;
  final double max;
  final double height;
  final bool dimmed;

  double _h(double minutes) =>
      max <= 0 ? 0 : (minutes / max).clamp(0.0, 1.0) * height;

  @override
  Widget build(BuildContext context) {
    final double opacity = dimmed ? 0.35 : 1;
    const Radius cap = Radius.circular(4);
    Widget seg(double h, Color color, {bool top = false}) => Container(
      height: h,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: top
            ? const BorderRadius.vertical(top: cap)
            : BorderRadius.zero,
      ),
    );

    final bool cardioTop = bar.cardio > 0;
    final bool strengthTop = !cardioTop && bar.strength > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (bar.cardio > 0)
            seg(_h(bar.cardio), AppColors.chartCardio, top: true),
          if (bar.strength > 0)
            seg(_h(bar.strength), AppColors.chartStrength, top: strengthTop),
          if (bar.stretch > 0)
            seg(
              _h(bar.stretch),
              AppColors.chartStretching,
              top: !cardioTop && !strengthTop,
            ),
          if (bar.total <= 0)
            Container(
              height: 2,
              decoration: const BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.vertical(top: cap),
              ),
            ),
        ],
      ),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  const _StackedBarPainter({
    required this.bars,
    required this.dayLabels,
    required this.todayIndex,
    required this.todayLabel,
    required this.goal,
    required this.goalLabel,
    required this.textDirection,
  });

  final List<ActivityBar> bars;
  final List<String> dayLabels;
  final int todayIndex;

  /// `CustomPainter` 는 BuildContext 가 없어 부르는 쪽이 문구를 넘긴다.
  final String todayLabel;

  /// 하루 목표(분)와 그 라벨. 가로선은 이 목표선 하나뿐이다 (#1015).
  final double goal;
  final String goalLabel;
  final TextDirection textDirection;

  /// 가장 바쁜 날을 20분 단위로 올려 잡는다 — 막대가 위로 잘리지 않는다.
  /// 기록이 하나도 없으면 90분 축으로 둔다.
  double get _max {
    double m = 0;
    for (final ActivityBar b in bars) {
      if (b.total > m) m = b.total;
    }
    if (m <= 0) return 90;
    return (m / 20).ceil() * 20;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const double left = 24;
    const double bottomPad = 24;
    final double chartH = size.height - bottomPad;
    final double max = _max;

    // 가로선은 목표선 하나다 (#1015). 눈금선 다섯 줄과 축 숫자를 함께 그리던
    // 자리인데, 목표선과 굵기·색이 비슷해 어느 선이 목표인지 읽히지 않았다.
    // 값은 막대 툴팁과 카드 머리의 요약이 말한다.
    if (goal > 0 && goal <= max) {
      final double goalY = chartH - (goal / max) * chartH;
      ChartGoalLine.paint(canvas, y: goalY, left: left, right: size.width);
      ChartGoalLine.paintLabel(
        canvas,
        y: goalY,
        right: size.width,
        text: goalLabel,
        textDirection: textDirection,
      );
    }

    final double slot = (size.width - left) / bars.length;
    // 칸의 일부만 채워 막대가 서로 붙지 않게 한다. 한 달(30칸)은 더 좁게.
    final double barW = math.min(slot * (bars.length > 10 ? 0.55 : 0.6), 40);
    for (int i = 0; i < bars.length; i++) {
      final ActivityBar b = bars[i];
      final double cx = left + slot * i + slot / 2;
      final double x = cx - barW / 2;
      final bool isToday = i == todayIndex;
      // 맨 위 구간만 모서리를 둥글린다 — 어떤 유형이 위에 오든 머리 모양이 같다.
      final bool cardioTop = b.cardio > 0;
      final bool strengthTop = !cardioTop && b.strength > 0;
      final bool stretchTop = !cardioTop && !strengthTop && b.stretch > 0;
      double yBottom = chartH;
      double h;
      h = (b.stretch / max) * chartH;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          AppColors.chartStretching,
          topRadius: stretchTop ? 4 : 0,
        );
        yBottom -= h;
      }
      h = (b.strength / max) * chartH;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          AppColors.chartStrength,
          topRadius: strengthTop ? 4 : 0,
        );
        yBottom -= h;
      }
      h = (b.cardio / max) * chartH;
      if (h > 0) {
        _rrect(
          canvas,
          x,
          yBottom - h,
          barW,
          h,
          AppColors.chartCardio,
          topRadius: cardioTop ? 4 : 0,
        );
        yBottom -= h;
      }
      if (b.total == 0) {
        // 기록이 없는 날의 그루터기. 아예 안 그리면 그날이 빠진 것처럼 보인다.
        _rrect(
          canvas,
          x,
          chartH - 3,
          barW,
          3,
          AppColors.inputBackground,
          topRadius: 1.5,
        );
      }
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: i < dayLabels.length ? dayLabels[i] : '',
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? AppColors.primary : AppColors.mutedForeground,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 5));
      if (isToday) {
        final TextPainter t2 = TextPainter(
          text: TextSpan(
            text: todayLabel,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        t2.paint(canvas, Offset(cx - t2.width / 2, chartH + 15));
      }
    }
  }

  void _rrect(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    Color color, {
    required double topRadius,
  }) {
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, w, h),
        topLeft: Radius.circular(topRadius),
        topRight: Radius.circular(topRadius),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.dayLabels != dayLabels ||
      oldDelegate.todayIndex != todayIndex;
}
