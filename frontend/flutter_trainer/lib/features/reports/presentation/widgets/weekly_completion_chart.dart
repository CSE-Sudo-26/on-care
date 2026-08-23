import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';

/// 주간 이행률 — 요일별 막대 위에 그 주의 꺾은선을 겹친다.
///
/// 막대만 있던 때에는 값을 하나씩 읽어 머릿속에서 이어야 흐름이 보였다.
/// 막대는 "그날 얼마나 했나", 꺾은선은 "주중에 어디서 무너졌나" 를 말한다 —
/// 주간 리포트가 답해야 하는 건 뒤엣것이다(#1177).
///
/// 두 그림이 **같은 좌표**를 쓴다. 선을 따로 그린 그래프를 아래에 붙이면
/// 눈금이 갈라져 같은 값이 두 높이로 보인다.
class WeeklyCompletionChart extends StatelessWidget {
  /// Creates the weekly completion chart.
  const WeeklyCompletionChart({
    super.key,
    required this.values,
    required this.labels,
    required this.semanticsLabel,
    required this.noRecordLabel,
    this.pendingFrom,
    this.missing = const <int>{},
    this.height = 118,
  }) : assert(values.length == labels.length, 'values/labels 길이가 달라요');

  /// 요일별 이행률(%). 0~100.
  final List<int> values;

  /// 요일 라벨(월→일).
  final List<String> labels;

  /// `CustomPaint` 는 시맨틱 트리에 아무것도 남기지 않는다 — 이 문장이 없으면
  /// 그래프가 음성 안내에서 통째로 사라진다.
  final String semanticsLabel;

  /// 기록이 없는 날에 적을 말. 로케일은 부르는 쪽만 안다.
  final String noRecordLabel;

  /// 아직 오지 않은 첫 요일. 이번 주에만 있다.
  final int? pendingFrom;

  /// 지난 날인데 기록이 없는 요일. 0% 로 그리면 '0% 수행'이라는 다른 뜻이 된다.
  final Set<int> missing;

  /// 막대 영역 높이(값 라벨·요일 라벨 제외).
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height:
              height +
              _WeeklyCompletionPainter.topPad +
              _WeeklyCompletionPainter.labelHeight,
          child: CustomPaint(
            painter: _WeeklyCompletionPainter(
              values: values,
              labels: labels,
              pendingFrom: pendingFrom ?? values.length,
              missing: missing,
              noRecordLabel: noRecordLabel,
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

class _WeeklyCompletionPainter extends CustomPainter {
  _WeeklyCompletionPainter({
    required this.values,
    required this.labels,
    required this.pendingFrom,
    required this.missing,
    required this.noRecordLabel,
    required this.textDirection,
    required this.base,
  });

  final List<int> values;
  final List<String> labels;
  final int pendingFrom;
  final Set<int> missing;
  final String noRecordLabel;
  final TextDirection textDirection;

  /// 화면의 기본 글자 모양. 크기·굵기·색만 이 위에 덧입힌다.
  final TextStyle base;

  /// 값 라벨이 들어갈 위쪽 여백. 100% 막대의 숫자가 카드 제목에 닿지 않는다.
  static const double topPad = 18;

  /// 요일 라벨 줄.
  static const double labelHeight = 20;

  /// 막대 최대 폭. 고객이 적은 주에 슬롯이 넓어져도 막대가 통짜 블록처럼
  /// 보이지 않게 잘라 둔다 — 예전 그래프가 못생겨 보인 이유의 절반이 이것이다.
  static const double maxBarWidth = 30;

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
    double topOf(int i) =>
        baseline - plotHeight * (values[i].clamp(0, 100) / 100);

    final Paint track = Paint()..color = AppColors.inputBackground;
    for (var i = 0; i < values.length; i++) {
      // 빈 트랙을 늘 깔아 둔다. 기록이 없는 날과 아직 오지 않은 날이 '자리는
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
      if (i >= pendingFrom || missing.contains(i)) continue;
      final double top = topOf(i);
      final Rect rect = Rect.fromLTRB(
        centerOf(i) - barWidth / 2,
        // 0% 도 2px 은 남긴다 — '기록했고 아무것도 못 했다' 와 '기록 없음' 은
        // 다른 말이다.
        top > baseline - 2 ? baseline - 2 : top,
        centerOf(i) + barWidth / 2,
        baseline,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(7)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.center.dx, rect.top),
            Offset(rect.center.dx, rect.bottom),
            <Color>[AppColors.chartStrength, AppColors.primary],
          ),
      );
    }

    // 꺾은선은 기록이 있는 날만 잇는다. 빈 날을 가로질러 이으면 그 사이에
    // 값이 있었던 것처럼 보인다.
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
      if (i >= pendingFrom || missing.contains(i)) {
        flush();
        continue;
      }
      run.add(Offset(centerOf(i), topOf(i)));
    }
    flush();

    for (var i = 0; i < values.length; i++) {
      if (i >= pendingFrom || missing.contains(i)) continue;
      final Offset point = Offset(centerOf(i), topOf(i));
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
        '${values[i]}%',
        Offset(point.dx, point.dy - 8),
        const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.foreground,
        ),
        anchorBottom: true,
      );
    }

    for (var i = 0; i < values.length; i++) {
      if (i < pendingFrom && !missing.contains(i)) continue;
      if (missing.contains(i)) {
        _text(
          canvas,
          noRecordLabel,
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
          fontWeight: FontWeight.w600,
          color: i >= pendingFrom
              ? AppColors.disabledForeground
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
  bool shouldRepaint(_WeeklyCompletionPainter old) =>
      !_sameInts(old.values, values) ||
      old.pendingFrom != pendingFrom ||
      !_sameSet(old.missing, missing) ||
      old.labels.join() != labels.join() ||
      old.noRecordLabel != noRecordLabel ||
      old.base != base;

  static bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
