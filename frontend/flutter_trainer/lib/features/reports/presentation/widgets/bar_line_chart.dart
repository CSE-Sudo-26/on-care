import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';

/// 막대 하나에 쌓는 조각(칼로리의 탄·단·지).
typedef BarSegment = ({double value, Color color});

/// 막대 위에 꺾은선을 겹친 그래프 — 리포트 탭의 **모든** 막대가 이 그림이다.
///
/// 막대는 "그 칸이 얼마나 되나", 꺾은선은 "칸에서 칸으로 어떻게 움직였나" 를
/// 말한다. 주간 이행률·주 대비 비교가 같은 위젯을 쓰므로, 한 화면 안에서 막대
/// 모양·값 위치·선 굵기가 갈리지 않는다(#1177).
///
/// 두 그림이 **같은 좌표**를 쓴다. 선을 따로 그린 그래프를 아래에 붙이면
/// 눈금이 갈라져 같은 값이 두 높이로 보인다.
class BarLineChart extends StatelessWidget {
  /// Creates the chart.
  const BarLineChart({
    super.key,
    required this.values,
    required this.labels,
    required this.ceiling,
    required this.format,
    required this.semanticsLabel,
    this.emptyLabel,
    this.pendingFrom,
    this.segments,
    this.goal,
    this.height = 118,
    this.maxBarWidth = 30,
    this.highlightIndex,
  }) : assert(values.length == labels.length, 'values/labels 길이가 달라요');

  /// 칸별 값. null 은 **기록이 없다**는 뜻이다 — 0 과 다르다.
  final List<double?> values;

  /// 칸 라벨(요일 또는 주).
  final List<String> labels;

  /// 눈금 끝. 0 이하면 1 로 본다.
  final double ceiling;

  /// 값을 단위까지 붙여 적는 방법.
  final String Function(double) format;

  /// `CustomPaint` 는 시맨틱 트리에 아무것도 남기지 않는다 — 이 문장이 없으면
  /// 그래프가 음성 안내에서 통째로 사라진다.
  final String semanticsLabel;

  /// 값이 없는 칸에 적을 말. null 이면 빈 트랙만 둔다.
  final String? emptyLabel;

  /// 아직 오지 않은 첫 칸. 그 뒤는 빈 트랙만 두고 아무 말도 적지 않는다 —
  /// 오지 않은 날은 "기록이 없다" 와 다르다.
  final int? pendingFrom;

  /// 칸별 누적 조각. 준 칸은 조각 색으로 쌓고, 안 준 칸은 한 색으로 채운다.
  final List<List<BarSegment>?>? segments;

  /// 넘으면 막대가 빨강이 되는 값. 없으면 늘 브랜드 색이다.
  final double? goal;

  /// 막대 영역 높이(값 라벨·칸 라벨 제외).
  final double height;

  /// 막대 최대 폭. 칸이 적은 그래프에서 막대가 통짜 블록처럼 보이지 않게 한다.
  final double maxBarWidth;

  /// 굵게 적을 칸(보고 있는 주).
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height:
              height + _BarLinePainter.topPad + _BarLinePainter.labelHeight,
          child: CustomPaint(
            painter: _BarLinePainter(
              values: values,
              labels: labels,
              ceiling: ceiling <= 0 ? 1 : ceiling,
              format: format,
              emptyLabel: emptyLabel,
              pendingFrom: pendingFrom ?? values.length,
              segments: segments,
              goal: goal,
              maxBarWidth: maxBarWidth,
              highlightIndex: highlightIndex,
              textDirection: Directionality.of(context),
              // `TextPainter` 는 위젯 트리 밖이라 앱 서체를 물려받지 않는다.
              // 넘겨 주지 않으면 이 그래프의 글자만 시스템 기본 서체로
              // 그려져, 같은 카드 안에서 서체가 갈린다.
              base: DefaultTextStyle.of(context).style,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _BarLinePainter extends CustomPainter {
  _BarLinePainter({
    required this.values,
    required this.labels,
    required this.ceiling,
    required this.format,
    required this.emptyLabel,
    required this.pendingFrom,
    required this.segments,
    required this.goal,
    required this.maxBarWidth,
    required this.highlightIndex,
    required this.textDirection,
    required this.base,
  });

  final List<double?> values;
  final List<String> labels;
  final double ceiling;
  final String Function(double) format;
  final String? emptyLabel;
  final int pendingFrom;
  final List<List<BarSegment>?>? segments;
  final double? goal;
  final double maxBarWidth;
  final int? highlightIndex;
  final TextDirection textDirection;

  /// 화면의 기본 글자 모양. 크기·굵기·색만 이 위에 덧입힌다.
  final TextStyle base;

  /// 값 라벨이 들어갈 위쪽 여백. 꽉 찬 막대의 숫자가 카드 제목에 닿지 않는다.
  static const double topPad = 18;

  /// 칸 라벨 줄.
  static const double labelHeight = 20;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final double plotHeight = size.height - topPad - labelHeight;
    if (plotHeight <= 0) return;
    final double baseline = topPad + plotHeight;
    final double slot = size.width / values.length;
    final double barWidth = slot * 0.46 > maxBarWidth
        ? maxBarWidth
        : slot * 0.46;

    double centerOf(int i) => slot * (i + 0.5);
    double topOf(double v) =>
        baseline - plotHeight * (v / ceiling).clamp(0.0, 1.0);
    bool drawn(int i) => i < pendingFrom && values[i] != null;

    final Paint track = Paint()..color = AppColors.inputBackground;
    for (var i = 0; i < values.length; i++) {
      // 빈 트랙을 늘 깔아 둔다. 기록이 없는 칸과 아직 오지 않은 칸이 '자리는
      // 있는데 값이 없다' 로 읽혀야 한다.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerOf(i) - barWidth / 2,
            topPad,
            barWidth,
            plotHeight,
          ),
          const Radius.circular(7),
        ),
        track,
      );
    }

    for (var i = 0; i < values.length; i++) {
      if (!drawn(i)) continue;
      final double value = values[i]!;
      final double top = topOf(value);
      final Rect rect = Rect.fromLTRB(
        centerOf(i) - barWidth / 2,
        // 0 도 2px 은 남긴다 — '기록했고 아무것도 못 했다' 와 '기록 없음' 은
        // 다른 말이다.
        top > baseline - 2 ? baseline - 2 : top,
        centerOf(i) + barWidth / 2,
        baseline,
      );
      final RRect bar = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(7),
      );
      final List<BarSegment>? stack = segments != null && i < segments!.length
          ? segments![i]
          : null;
      final double stackTotal =
          stack?.fold<double>(0, (sum, s) => sum + s.value) ?? 0;
      if (stack != null && stackTotal > 0) {
        // 조각은 막대 안에서만 그린다 — 둥근 모서리 밖으로 새면 막대가 아니라
        // 색 띠 셋으로 보인다.
        canvas.save();
        canvas.clipRRect(bar);
        var y = rect.bottom;
        for (final segment in stack) {
          final double h = rect.height * (segment.value / stackTotal);
          canvas.drawRect(
            Rect.fromLTRB(rect.left, y - h, rect.right, y),
            Paint()..color = segment.color,
          );
          y -= h;
        }
        canvas.restore();
      } else {
        final Paint fill = Paint();
        // 목표를 넘긴 막대는 한 색으로 칠한다 — 그러데이션 위에 빨강을 얹으면
        // 넘겼다는 사실이 색결에 묻힌다.
        if (goal != null && value > goal!) {
          fill.color = AppColors.overTarget;
        } else {
          fill.shader = ui.Gradient.linear(
            Offset(rect.center.dx, rect.top),
            Offset(rect.center.dx, rect.bottom),
            <Color>[AppColors.chartStrength, AppColors.primary],
          );
        }
        canvas.drawRRect(bar, fill);
      }
    }

    // 꺾은선은 값이 있는 칸만 잇는다. 빈 칸을 가로질러 이으면 그 사이에 값이
    // 있었던 것처럼 보인다.
    final List<Offset> run = <Offset>[];
    void flush() {
      if (run.length > 1) {
        final Path path = Path()..moveTo(run.first.dx, run.first.dy);
        for (final point in run.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.accentDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      run.clear();
    }

    for (var i = 0; i < values.length; i++) {
      if (!drawn(i)) {
        flush();
        continue;
      }
      run.add(Offset(centerOf(i), topOf(values[i]!)));
    }
    flush();

    for (var i = 0; i < values.length; i++) {
      if (!drawn(i)) continue;
      final Offset point = Offset(centerOf(i), topOf(values[i]!));
      canvas.drawCircle(point, 4, Paint()..color = AppColors.card);
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = AppColors.accentDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _text(
        canvas,
        format(values[i]!),
        Offset(point.dx, point.dy - 8),
        TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: goal != null && values[i]! > goal!
              ? AppColors.overTarget
              : AppColors.foreground,
        ),
        anchorBottom: true,
        maxWidth: slot,
      );
    }

    if (emptyLabel != null) {
      for (var i = 0; i < values.length; i++) {
        if (drawn(i) || i >= pendingFrom) continue;
        _text(
          canvas,
          emptyLabel!,
          Offset(centerOf(i), baseline - 6),
          const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.disabledForeground,
          ),
          anchorBottom: true,
          maxWidth: slot,
        );
      }
    }

    for (var i = 0; i < labels.length; i++) {
      _text(
        canvas,
        labels[i],
        Offset(centerOf(i), baseline + 5),
        TextStyle(
          fontSize: 11.5,
          fontWeight: highlightIndex == i
              ? FontWeight.w800
              : FontWeight.w600,
          color: i >= pendingFrom
              ? AppColors.disabledForeground
              : highlightIndex == i
              ? AppColors.primary
              : AppColors.subtleForeground,
        ),
        maxWidth: slot,
      );
    }
  }

  /// 가운데 정렬로 한 줄 적는다. [anchorBottom] 이면 [at] 이 글자의 **아래**다.
  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool anchorBottom = false,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: base.merge(style)),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(
      canvas,
      Offset(
        at.dx - painter.width / 2,
        anchorBottom ? at.dy - painter.height : at.dy,
      ),
    );
  }

  @override
  bool shouldRepaint(_BarLinePainter old) =>
      !_sameValues(old.values, values) ||
      old.ceiling != ceiling ||
      old.pendingFrom != pendingFrom ||
      old.goal != goal ||
      old.emptyLabel != emptyLabel ||
      old.highlightIndex != highlightIndex ||
      old.maxBarWidth != maxBarWidth ||
      old.labels.join() != labels.join() ||
      old.segments != segments ||
      old.base != base;

  static bool _sameValues(List<double?> a, List<double?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
