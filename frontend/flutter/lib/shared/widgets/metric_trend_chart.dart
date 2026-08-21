/// 지표 하나의 주간 추이 꺾은선 — 홈 탭과 식단 탭이 **같은 그림**을 쓴다.
///
/// 원래 홈 탭(`dashboard_content.dart`) 안에만 있던 차트다. 식단 탭의 주간
/// 그래프가 막대라 같은 값을 두 가지 모양으로 보여 주고 있었다. 복사하면 한쪽만
/// 고쳐져 갈라지므로 여기로 옮기고 양쪽이 이것을 부른다.
///
/// 그리는 규칙은 옮기기 전과 같다.
///
///  * 선은 **오늘까지만** 잇는다 — 아직 오지 않은 요일의 0 이 급락처럼 보이지
///    않도록. x 좌표는 7칸 기준 그대로라 주끼리 정렬된다.
///  * 점 색은 그날이 목표를 넘겼는지만 말한다(초과=빨강, 그 외=초록). 지표
///    카드의 뱃지와 같은 두 색이라 한 카드 안에서 서로 다른 이야기를 하지 않는다.
///  * 목표선은 그리지 않는다. 눈금과 겹치면 선이 두꺼워 보였다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/charts/goal_line.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 이번 주 꺾은선의 색. 값의 상태는 점으로 말하므로 선은 눈에 띄지 않게 둔다.
const Color kMetricTrendLine = Color(0xFFDDE2E8);

/// 목표 대비 상태색: 초과(빨강) / 그 외(초록).
///
/// 목표가 0 이면 초과로 보지 않는다. `v > goal` 만 두면 목표가 없는 지표의 **모든**
/// 기록이 빨간 점이 되어, 같은 카드의 평균 뱃지(목표가 있을 때만 초과 판정)와 서로
/// 다른 이야기를 한다.
Color metricStatusColor(double v, double goal) =>
    goal > 0 && v > goal ? FigmaColors.dangerRed : FigmaColors.greenText;

/// 월→일 요일 라벨. 홈 탭과 식단 탭이 **같은 문구**를 쓰도록 여기 둔다 — 한쪽만
/// 하드코딩하면 영어 로케일에서 한글 요일이 그대로 남는다.
List<String> weekDayLabels(AppLocalizations l) => <String>[
  l.dietWeekdayMon,
  l.dietWeekdayTue,
  l.dietWeekdayWed,
  l.dietWeekdayThu,
  l.dietWeekdayFri,
  l.dietWeekdaySat,
  l.dietWeekdaySun,
];

/// 소수 첫째 자리까지만 남기고 정수는 콤마만. 당류 17.8 이 18 로 반올림돼
/// 지표 카드·식단 탭 수치와 어긋나지 않도록.
String metricTrendNumber(num v) => v == v.roundToDouble()
    ? NumberFormat('#,###').format(v)
    : NumberFormat('#,##0.#').format(v);

/// 데이터와 눈금을 모두 담는 스케일. **0 을 바닥으로 두지 않는다** — 두면
/// 하루하루 차이가 거의 평평한 선으로 뭉개진다.
(double, double) metricTrendScale({
  required List<double> values,
  required List<double> ticks,
  required double goal,
}) {
  final List<double> all = <double>[...values, ...ticks, goal];
  double lo = all.reduce(math.min);
  double hi = all.reduce(math.max);
  final double range = (hi - lo) == 0 ? 1 : (hi - lo);
  hi += range * 0.10;
  lo -= range * 0.08;
  // 당류처럼 0이 최소 눈금인 지표는 바닥을 0에 고정.
  if (ticks.isNotEmpty && ticks.first <= 0 && lo < 0) lo = 0;
  return (lo, hi);
}

/// 눈금 라벨 + 꺾은선 + 요일 라벨 한 덩어리.
class MetricTrendChart extends StatelessWidget {
  const MetricTrendChart({
    required this.values,
    required this.dayLabels,
    required this.goal,
    required this.ticks,
    required this.todayIndex,
    required this.replayKey,
    required this.semanticsLabel,
    this.goalLabel,
    required this.formatTick,
    this.height = 68,
    super.key,
  });

  /// 요일별 값(월→일). [dayLabels] 와 길이가 같아야 한다.
  final List<double> values;
  final List<String> dayLabels;
  final double goal;

  /// 축의 위아래를 정하는 값들. 그리지는 않는다 — 지표별 축 성질을 잡는
  /// [metricTrendScale] 의 입력이다.
  final List<double> ticks;

  /// 선을 여기까지만 잇는다. 지난 주처럼 전부 지난 구간이면 마지막 index.
  final int todayIndex;

  /// 바뀌면 진입 애니메이션을 처음부터 다시 그린다.
  final Object replayKey;

  /// 그래프가 말하는 내용 한 문장. `CustomPaint` 는 시맨틱 트리에 아무 노드도
  /// 남기지 않아, 이게 없으면 그래프가 음성 안내에서 통째로 사라진다(#972).
  /// [chartSemanticsLabel] 로 만든다 — 지표 이름과 단위는 부르는 쪽만 안다.
  final String semanticsLabel;

  /// 목표선에 붙는 문구(예: `목표 2,000`). null 이면 선만 그린다. 문구를 밖에서
  /// 받는 것은 두 앱의 로케일 자원이 갈라져 있어서다.
  final String? goalLabel;

  final String Function(double) formatTick;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (double lo, double hi) = metricTrendScale(
      values: values,
      ticks: ticks,
      goal: goal,
    );
    // 눈금·요일 라벨은 낱개로 읽어 봐야 `월` `화` 뿐이라 그래프가 무슨 값을
    // 말하는지 알 수 없다. 한 덩어리로 묶고 요약 한 문장만 읽힌다.
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 목표선의 실제 높이에 맞춰 라벨 하나. 칸은 목표가 없어도 자리를
            // 지킨다 — 지표를 바꿀 때 그래프 폭이 흔들리지 않는다.
            //
            // 폭은 눈금 라벨이 쓰던 38 그대로다. `목표 2,000` 을 한 줄로 두면 이
            // 칸이 넓어져야 하는데, 그러면 360px 영어 로케일에서 요일 라벨 줄이
            // 넘친다. 두 줄로 접어 폭을 지킨다.
            Builder(
              builder: (BuildContext context) {
                // 칸도 글씨 배율을 따라간다 (#1004). 38·26 으로 박아 두면 배율이
                // 올라간 순간 `목표` 아래 줄(`2,000`)이 상자에 눌려 반만 보인다.
                final TextScaler ts = MediaQuery.textScalerOf(context);
                final double labelWidth = 38 * ts.scale(1);
                // 두 줄(`목표` / 값)이 들어갈 높이를 글씨에서 잰다. 상수로 두면
                // 배율이 오른 순간 아랫줄이 잘린다. (#1004)
                final double labelHeight = ts.scale(_axisLabelSize) * 1.35 * 2;
                return SizedBox(
                  width: labelWidth,
                  height: height,
                  child: Stack(
                    children: <Widget>[
                      if (goalLabel != null &&
                          goal > 0 &&
                          goal >= lo &&
                          goal <= hi)
                        Positioned(
                          right: 0,
                          top:
                              (height -
                                      ((goal - lo) / (hi - lo)) * height -
                                      labelHeight / 2)
                                  .clamp(0.0, height - labelHeight),
                          child: SizedBox(
                            key: chartGoalLabelKey,
                            height: labelHeight,
                            child: Center(child: _AxisLabel(goalLabel!)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: height,
                    child: ChartReveal(
                      replayKey: replayKey,
                      builder: (BuildContext context, double t) => CustomPaint(
                        size: Size.infinite,
                        painter: MetricTrendPainter(
                          cur: values,
                          goal: goal,
                          ticks: ticks,
                          lo: lo,
                          hi: hi,
                          todayIndex: todayIndex,
                          progress: t,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      for (int i = 0; i < dayLabels.length; i++)
                        if (i == todayIndex)
                          // 오늘: 브랜드색 원 안에 흰 글씨.
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: FigmaColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              dayLabels[i],
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          Text(
                            dayLabels[i],
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 목표선 라벨 칸. 높이가 글씨 배율을 따라 달라져서, 크기로 찾을 수 없다.
const Key chartGoalLabelKey = ValueKey<String>('chart-goal-label');

/// 축 라벨 글씨 크기. 라벨 칸 높이를 이 값에서 재므로 한 곳에 둔다. (#1004)
const double _axisLabelSize = 10;

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.right,
    maxLines: 2,
    style: const TextStyle(
      fontSize: _axisLabelSize,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedForeground,
    ),
  );
}

/// 꺾은선 본체. 홈 탭에 있던 `_TrendChartPainter` 를 그대로 옮긴 것이다.
class MetricTrendPainter extends CustomPainter {
  MetricTrendPainter({
    required this.cur,
    required this.goal,
    required this.ticks,
    required this.lo,
    required this.hi,
    required this.todayIndex,
    this.progress = 1,
  });

  final List<double> cur;
  final double goal;
  final List<double> ticks;
  final double lo;
  final double hi;

  /// 선을 여기까지만 그린다(미래 요일의 0값이 급락처럼 보이지 않도록).
  final int todayIndex;

  /// 0 → 1 진입 애니메이션 진행도. 선은 월요일부터 오늘 쪽으로 이어지고,
  /// 각 데이터 포인트와 값 라벨은 선이 도달하는 순간 나타난다.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double span = (hi - lo) <= 0 ? 1 : (hi - lo);
    double dx(int i) => cur.length <= 1 ? w / 2 : (i / (cur.length - 1)) * w;
    double dy(double v) => h - ((v - lo) / span) * h;

    // 목표선 하나. 점선이라 데이터 꺾은선과 경쟁하지 않는다. 축 밖으로 나가는
    // 목표(범위를 벗어난 주)는 그리지 않는다 — 가장자리에 붙어 테두리처럼
    // 보인다.
    if (goal > 0 && goal >= lo && goal <= hi) {
      // 네 그래프가 같은 모양의 목표선을 쓴다 (#1015).
      ChartGoalLine.paint(canvas, y: dy(goal), left: 0, right: w);
    }

    final int lastIdx = todayIndex.clamp(0, cur.length - 1);
    final List<Offset> pts = <Offset>[
      for (int i = 0; i <= lastIdx; i++) Offset(dx(i), dy(cur[i])),
    ];

    final double p = progress.clamp(0.0, 1.0);
    final double drawn = lastIdx * p;
    if (lastIdx > 0) {
      final Path line = Path()..moveTo(pts.first.dx, pts.first.dy);
      final int whole = drawn.floor().clamp(0, lastIdx);
      for (int i = 1; i <= whole; i++) {
        line.lineTo(pts[i].dx, pts[i].dy);
      }
      if (whole < lastIdx) {
        final Offset tip = Offset.lerp(
          pts[whole],
          pts[whole + 1],
          drawn - whole,
        )!;
        line.lineTo(tip.dx, tip.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = kMetricTrendLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    for (int i = 0; i <= lastIdx; i++) {
      // 선이 이 점에 닿기 직전부터 짧게 페이드인한다.
      final double a = lastIdx == 0
          ? p
          : ((drawn - i) / 0.35 + 1).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final Color sc = metricStatusColor(cur[i], goal);
      _dot(canvas, pts[i], sc, r: i == cur.length - 1 ? 5.0 : 4.2, alpha: a);
      _text(canvas, metricTrendNumber(cur[i]), pts[i], w, sc, alpha: a);
    }
  }

  void _dot(
    Canvas c,
    Offset o,
    Color color, {
    double r = 3.0,
    double alpha = 1,
  }) {
    c.drawCircle(
      o,
      r + 1.3,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    c.drawCircle(o, r, Paint()..color = color.withValues(alpha: alpha));
  }

  void _text(
    Canvas c,
    String s,
    Offset at,
    double w,
    Color color, {
    double alpha = 1,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: alpha),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final double bx = (at.dx - tp.width / 2).clamp(0.0, w - tp.width);
    double by = at.dy - tp.height - 7;
    if (by < 0) by = at.dy + 7;
    tp.paint(c, Offset(bx, by));
  }

  @override
  bool shouldRepaint(covariant MetricTrendPainter old) =>
      old.cur != cur ||
      old.goal != goal ||
      old.ticks != ticks ||
      old.lo != lo ||
      old.hi != hi ||
      old.todayIndex != todayIndex ||
      old.progress != progress;
}
