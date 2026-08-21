/// 운동 그래프 — 회원 앱 운동 탭 `운동 현황` 과 **같은 그림**이다. (#943, #1077)
///
/// 회원 앱 `features/exercise/presentation/widgets/exercise_activity_status.dart`
/// 의 도넛·링·막대를 트레이너 콘솔 토큰으로 옮긴 것이다. 두 앱은 패키지가 갈라져
/// 있어 코드를 공유할 수 없으므로, 규칙을 여기에도 적어 둔다 —
/// `metric_trend_chart` 를 옮겨 둔 것과 같은 방식이다. 한쪽만 고치면 회원이 보는
/// 그래프와 트레이너가 보는 그래프가 다른 이야기를 한다.
///
///  * 축은 **소모 칼로리**다. 유산소는 분, 근력은 세트, 스트레칭은 분으로 재는
///    값이라 서로 더할 수 없는데, 칼로리는 셋이 함께 만든 하나의 결과다.
///  * 유형 순서는 언제나 유산소 → 근력 → 스트레칭이다. 링도 목록도 같은 순서라,
///    색을 외우지 않아도 자리로 읽힌다.
///  * 목표가 없는 `기타` 는 그리지 않고 분 수만 적는다.
///  * 기록이 없는 날은 3px 짜리 회색 그루터기다. 0 을 아예 안 그리면 그날이
///    빠진 것처럼 보이고, 색을 주면 짧은 운동을 한 것처럼 보인다.
///
/// 회원 앱에는 진입 애니메이션이 있지만 여기서는 정적으로 그린다. 트레이너
/// 콘솔의 다른 차트(`BarSeriesChart`)도 정적이라, 한 화면에서 어떤 그래프는
/// 자라고 어떤 그래프는 이미 서 있으면 그게 더 튄다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/exercise_burn_goals.dart';
import 'package:oncare_trainer/shared/widgets/chart_semantics.dart';
import 'package:oncare_trainer/shared/widgets/goal_line.dart';
import 'package:oncare_trainer/shared/widgets/period_scroll_chart.dart';

/// 소모 칼로리 색. 콘솔의 브랜드 색을 그대로 쓴다.
const Color kBurnColor = AppColors.primary;

/// 유형 색 — 회원 앱과 같은 순서·같은 농담이다.
Color kindColor(ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => AppColors.chartCardio,
  ExerciseKind.strength => AppColors.chartStrength,
  ExerciseKind.stretching => AppColors.chartStretching,
};

/// 유형 이름.
String kindLabel(AppLocalizations l, ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => l.routineTypeCardio,
  ExerciseKind.strength => l.routineTypeStrength,
  ExerciseKind.stretching => l.routineTypeStretching,
};

/// 유형의 값을 **그 유형의 단위**로 — 유산소·스트레칭은 분, 근력은 세트.
String kindValueText(AppLocalizations l, ExerciseKind kind, num value) =>
    switch (kind) {
      ExerciseKind.cardio ||
      ExerciseKind.stretching => l.minutesShort(value.round()),
      ExerciseKind.strength => l.exSetsValue(value.round()),
    };

/// 하루/기간의 유형별 값 한 벌. 단위가 서로 다르므로 더하지 않는다.
class ActivitySplit {
  /// Creates one split.
  const ActivitySplit({
    this.cardioMinutes = 0,
    this.strengthSets = 0,
    this.stretchingMinutes = 0,
    this.otherMinutes = 0,
  });

  final num cardioMinutes;
  final num strengthSets;
  final num stretchingMinutes;

  /// 목표가 없는 나머지 운동. 그래프에는 그리지 않는다.
  final num otherMinutes;

  num valueOf(ExerciseKind kind) => switch (kind) {
    ExerciseKind.cardio => cardioMinutes,
    ExerciseKind.strength => strengthSets,
    ExerciseKind.stretching => stretchingMinutes,
  };
}

/// `오늘` — 소모 칼로리 도넛 하나 + 유형별로 얼마나 했는지 적은 줄.
class BurnDonut extends StatelessWidget {
  /// Creates the donut.
  const BurnDonut({
    super.key,
    required this.calories,
    required this.goal,
    required this.split,
    required this.title,
  });

  final int calories;

  /// 하루 소모 목표(kcal). 0 이면 트랙만 그린다.
  final double goal;
  final ActivitySplit split;

  /// 오른쪽 열 머리글 — `오늘 소모`.
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox(
      height: 170,
      // 좁은 화면에서 고정폭 도넛 + 목록이 넘치지 않도록 통째로 줄인다.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 116,
              height: 116,
              // 도넛은 `CustomPaint` 라 시맨틱 트리에 노드를 남기지 않고, 가운데
              // 숫자는 `411` 과 `kcal` 두 조각으로 흩어져 읽힌다. 한 덩어리로
              // 묶어 무엇의 몇 kcal 인지 한 문장으로 말한다(#972).
              child: Semantics(
                container: true,
                label: chartSemanticsLabel(
                  l,
                  title: title,
                  points: calories == 0
                      ? const <String>[]
                      : <String>['$calories${l.unitKcal}'],
                ),
                child: ExcludeSemantics(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: const Size.square(116),
                        painter: _BurnDonutPainter(
                          ratio: goal <= 0 ? 0 : calories / goal,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '$calories',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                              height: 1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            l.unitKcal,
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
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeadlineLine(
                    caption: title,
                    value: '$calories/${goal.round()}',
                    unit: l.unitKcal,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ExerciseKind kind in ExerciseKind.values)
                    ActivityValueRow(
                      label: kindLabel(l, kind),
                      value: kindValueText(l, kind, split.valueOf(kind)),
                    ),
                  if (split.otherMinutes > 0)
                    ActivityValueRow(
                      label: l.exTypeOther,
                      value: l.minutesShort(split.otherMinutes.round()),
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

/// `이번 주` — 유형별 주간 목표를 크기 순으로 겹친 세 링 + 유형별 진행.
class BurnGoalRings extends StatelessWidget {
  /// Creates the rings.
  const BurnGoalRings({
    super.key,
    required this.calories,
    required this.split,
    required this.title,
  });

  final int calories;
  final ActivitySplit split;
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<double> ratios = <double>[
      for (final ExerciseKind kind in ExerciseKind.values)
        split.valueOf(kind) / weeklyGoalOf(kind),
    ];
    return SizedBox(
      height: 170,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 116,
              height: 116,
              child: Semantics(
                container: true,
                label: chartSemanticsLabel(
                  l,
                  title: title,
                  points: <String>[
                    for (int i = 0; i < ExerciseKind.values.length; i++)
                      '${kindLabel(l, ExerciseKind.values[i])} ${(ratios[i] * 100).round()}%',
                  ],
                ),
                child: ExcludeSemantics(
                  child: CustomPaint(
                    size: const Size.square(116),
                    painter: _GoalRingsPainter(ratios),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
            SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeadlineLine(
                    caption: title,
                    value: '$calories/${kWeeklyBurnKcal.round()}',
                    unit: l.unitKcal,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ExerciseKind kind in ExerciseKind.values)
                    ActivityValueRow(
                      color: kindColor(kind),
                      label: kindLabel(l, kind),
                      value: '${split.valueOf(kind).round()}',
                      goal: '/${kindValueText(l, kind, weeklyGoalOf(kind))}',
                    ),
                  if (split.otherMinutes > 0)
                    ActivityValueRow(
                      color: AppColors.border,
                      label: l.exTypeOther,
                      value: l.minutesShort(split.otherMinutes.round()),
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

/// `소모  411/300 kcal` — 한 줄짜리 머리.
class _HeadlineLine extends StatelessWidget {
  const _HeadlineLine({
    required this.caption,
    required this.value,
    required this.unit,
  });

  final String caption;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          caption,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    ),
  );
}

/// `▪ 유산소   145/150분` — 유형 한 줄.
class ActivityValueRow extends StatelessWidget {
  /// Creates one row.
  const ActivityValueRow({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.goal,
  });

  final String label;
  final String value;

  /// 색 점. 옆에 같은 색 링이 있는 화면에서만 준다.
  final Color? color;

  /// `/150분` 처럼 값 뒤에 붙는 목표. 값보다 연하게 적는다.
  final String? goal;

  @override
  Widget build(BuildContext context) {
    final Color? c = color;
    final String? g = goal;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          if (c != null) ...<Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: value),
                if (g != null)
                  TextSpan(
                    text: g,
                    style: const TextStyle(color: AppColors.mutedForeground),
                  ),
              ],
            ),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 범례 한 줄 — 색 사각형 + 이름. 식단 기간 카드가 함께 쓴다.
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

/// `이번 달` — 일별 소모 칼로리 막대. 한 칸을 고르면 그날 내역이 뜬다.
class BurnBarChart extends StatelessWidget {
  /// Creates the chart.
  const BurnBarChart({
    super.key,
    required this.calories,
    required this.splits,
    required this.dates,
    required this.title,
    required this.selection,
    this.dailyGoalKcal = kDailyBurnKcal,
  });

  final List<int> calories;
  final List<ActivitySplit> splits;
  final List<DateTime> dates;

  /// 그래프가 무엇을 그린 것인지 — 기록이 하나도 없는 기간에 비어 있다고 말할
  /// 때 이 이름으로 부른다(#972).
  final String title;
  final PeriodChartSelection selection;

  /// 하루 소모 목표(kcal). 0 이면 목표선을 그리지 않는다.
  final double dailyGoalKcal;

  /// 막대 하나의 툴팁 — 소모 칼로리와 그날의 유형별 내역.
  List<InlineSpan> _tipSpans(AppLocalizations l, int i) {
    final ActivitySplit s = splits[i];
    final List<String> rows = <String>[
      for (final ExerciseKind kind in ExerciseKind.values)
        if (s.valueOf(kind) > 0)
          '${kindLabel(l, kind)}   ${kindValueText(l, kind, s.valueOf(kind))}',
      if (s.otherMinutes > 0)
        '${l.exTypeOther}   ${l.minutesShort(s.otherMinutes.round())}',
    ];
    if (calories[i] <= 0 && rows.isEmpty) {
      return <InlineSpan>[TextSpan(text: l.chartNoRecord)];
    }
    return <InlineSpan>[
      TextSpan(text: '${calories[i]}${l.unitKcal}'),
      if (rows.isNotEmpty) TextSpan(text: '\n${rows.join('\n')}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool empty = calories.every((int c) => c <= 0);
    const double chartHeight = 150;
    final double peak = <double>[
      dailyGoalKcal,
      for (final int c in calories) c.toDouble(),
    ].fold<double>(1, (double a, double b) => math.max(a, b));
    final double max = peak * 1.15;
    final int labelStep = (calories.length / 12).ceil().clamp(1, 7);

    return Semantics(
      container: true,
      label: empty
          ? chartSemanticsLabel(l, title: title, points: const <String>[])
          : null,
      child: ExcludeSemantics(
        excluding: empty,
        child: ListenableBuilder(
          listenable: selection,
          builder: (BuildContext context, Widget? _) => PeriodScrollChart(
            count: calories.length,
            height: chartHeight,
            selectedIndex: selection.selected,
            onSelected: selection.select,
            onVisibleRangeChanged: selection.setVisible,
            goalOverlay: GoalLineOverlay(
              visible: dailyGoalKcal > 0,
              bottom: chartHeight * (dailyGoalKcal / max).clamp(0.0, 1.0),
              label:
                  '${l.clientPeriodGoal} '
                  '${dailyGoalKcal.round()}${l.unitKcal}',
            ),
            labelBuilder: (int i) =>
                i < dates.length && i % labelStep == 0 ? '${dates[i].day}' : '',
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
                children: _tipSpans(l, i),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderStrong),
                boxShadow: kCardShadow,
              ),
              child: _BurnBarColumn(
                value: calories[i].toDouble(),
                max: max,
                height: chartHeight,
                dimmed: selection.selected != null && selection.selected != i,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 막대 한 칸.
class _BurnBarColumn extends StatelessWidget {
  const _BurnBarColumn({
    required this.value,
    required this.max,
    required this.height,
    required this.dimmed,
  });

  final double value;
  final double max;
  final double height;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) {
      // 기록이 없는 날은 0 짜리 막대가 아니라 그루터기다.
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Opacity(
        opacity: dimmed ? 0.35 : 1,
        child: Container(
          height: math.max((value / max).clamp(0.0, 1.0) * height, 3),
          decoration: const BoxDecoration(
            color: kBurnColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
      ),
    );
  }
}

/// 소모 칼로리 도넛. 목표를 넘기면 한 바퀴를 넘어 계속 돈다.
class _BurnDonutPainter extends CustomPainter {
  _BurnDonutPainter({required this.ratio});

  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double stroke = size.width * 0.13;
    final double r = size.width / 2 - stroke / 2;
    paintRing(canvas, c, r, stroke, ratio, kBurnColor);
  }

  @override
  bool shouldRepaint(covariant _BurnDonutPainter old) => old.ratio != ratio;
}

/// 유형별 주간 목표를 크기 순으로 겹친 세 링.
class _GoalRingsPainter extends CustomPainter {
  _GoalRingsPainter(this.ratios);

  final List<double> ratios;

  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final double hole = radius * 0.22;
    final double stroke = (radius - _gap * 2 - hole) / 3;
    double r = radius - stroke / 2;
    for (int i = 0; i < ratios.length; i++) {
      paintRing(
        canvas,
        c,
        r,
        stroke,
        ratios[i],
        kindColor(ExerciseKind.values[i]),
      );
      r -= stroke + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GoalRingsPainter old) => old.ratios != ratios;
}

/// 링 하나 — 트랙 + 채운 호. 목표를 넘기면 한 바퀴를 넘어 이어 그리고, 겹친
/// 끝 아래에 그림자를 깔아 어디서 멈췄는지 보이게 한다. 그림자는 그 링의
/// 두께로 잘라 밖으로 번지지 않는다.
void paintRing(
  Canvas canvas,
  Offset center,
  double radius,
  double stroke,
  double ratio,
  Color color,
) {
  final Rect rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.16),
  );
  if (ratio <= 0) return;
  final Paint arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..color = color;
  if (ratio >= 1) {
    // 한 바퀴는 **끝이 없는 원**으로. 2π 원호에 둥근 끝을 주면 시작과 끝의
    // 캡이 같은 자리에 겹쳐 혹처럼 튀어나온다.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color,
    );
    final double over = math.min(ratio - 1, 1);
    _paintCapShadow(
      canvas,
      center,
      radius,
      stroke,
      -math.pi / 2 + math.pi * 2 * over,
    );
    if (over > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * over, false, arc);
    }
    return;
  }
  _paintCapShadow(
    canvas,
    center,
    radius,
    stroke,
    -math.pi / 2 + math.pi * 2 * ratio,
  );
  canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * ratio, false, arc);
}

void _paintCapShadow(
  Canvas canvas,
  Offset center,
  double radius,
  double stroke,
  double capAngle,
) {
  final Path ring = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: center, radius: radius + stroke / 2))
    ..addOval(Rect.fromCircle(center: center, radius: radius - stroke / 2));
  final Offset cap =
      center + Offset(math.cos(capAngle), math.sin(capAngle)) * radius;
  canvas
    ..save()
    ..clipPath(ring)
    ..drawCircle(
      cap,
      stroke / 2 + 1,
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    )
    ..drawCircle(
      cap,
      stroke / 2,
      Paint()
        ..color = const Color(0x4D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    )
    ..restore();
}
