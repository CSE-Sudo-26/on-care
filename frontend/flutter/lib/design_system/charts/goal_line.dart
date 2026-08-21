import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/colors.dart';

/// 그래프의 목표선 — 두 앱이 같은 모양으로 그린다. (#1015)
///
/// **가로선은 이것 하나뿐이다.** 예전에는 눈금선(0·25%·50%·75%·100%)이 함께
/// 그려졌는데, 목표선과 굵기·색이 비슷해 어느 선이 목표인지 읽히지 않았다.
/// 눈금은 값을 대강 가늠하게 해 주지만, 이 그래프들이 답해야 하는 질문은
/// "오늘이 목표 안인가" 하나다.
///
/// 점선인 이유는 데이터(막대·꺾은선)와 경쟁하지 않기 위해서다. 실선이면 목표가
/// 데이터처럼 보이고, 막대 위에 겹칠 때 막대를 자르는 것처럼 보인다.
class ChartGoalLine {
  ChartGoalLine._();

  static const Color color = AppColors.chartGoalLine;
  static const double strokeWidth = 1;
  static const double dashWidth = 4;
  static const double dashGap = 3;

  /// 라벨 글씨 크기. 라벨 칸을 재는 쪽도 이 값을 쓴다.
  static const double labelFontSize = 10;

  /// [y] 높이에 [left]~[right] 구간의 점선을 긋는다.
  static void paint(
    Canvas canvas, {
    required double y,
    required double left,
    required double right,
  }) {
    final Paint dash = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    for (double x = left; x < right; x += dashWidth + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, right), y),
        dash,
      );
    }
  }

  /// 선 위에 붙는 `목표 N` 라벨을 그린다. 오른쪽 끝에 붙이고, 선 위로 띄운다 —
  /// 아래에 두면 목표에 가까운 막대의 꼭대기와 겹친다.
  static void paintLabel(
    Canvas canvas, {
    required double y,
    required double right,
    required String text,
    required TextDirection textDirection,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: labelFontSize,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    tp.paint(canvas, Offset(right - tp.width, y - tp.height - 2));
  }
}

/// Stack 위에 얹는 목표선. 막대를 위젯으로 그리는 그래프(식단 기간 뷰)가 쓴다.
///
/// [bottom] 은 그래프 바닥에서 목표선까지의 거리다 — 호출부가 자기 축 계산으로
/// 넘긴다. 목표가 축 밖이면(0 이하거나 최댓값을 넘으면) 아무것도 그리지 않는다.
class GoalLineOverlay extends StatelessWidget {
  const GoalLineOverlay({
    super.key,
    required this.bottom,
    required this.label,
    this.visible = true,
  });

  final double bottom;
  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: CustomPaint(
        painter: _GoalLinePainter(
          label: label,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        ),
        // 선 자체는 높이가 없다. 라벨이 선 위로 올라가야 해서 칸만 잡아 둔다.
        child: const SizedBox(height: 0, width: double.infinity),
      ),
    );
  }
}

class _GoalLinePainter extends CustomPainter {
  const _GoalLinePainter({
    required this.label,
    required this.textDirection,
    required this.textScaler,
  });

  final String label;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    ChartGoalLine.paint(canvas, y: 0, left: 0, right: size.width);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: ChartGoalLine.labelFontSize,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: ChartGoalLine.color,
        ),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width, -tp.height - 2));
  }

  @override
  bool shouldRepaint(_GoalLinePainter old) =>
      old.label != label || old.textScaler != textScaler;
}
