import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';

/// 그래프의 목표선 — 두 앱이 같은 모양으로 그린다. (#1015)
///
/// 회원 앱 `design_system/charts/goal_line.dart` 와 같은 내용이다. 두 앱은 서로
/// 다른 패키지라 위젯을 공유할 수 없어, 같은 그림을 두 곳에 둔다.
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
}

/// Stack 위에 얹는 목표선. 막대를 위젯으로 그리는 그래프(식단 기간 뷰)가 쓴다.
///
/// [bottom] 은 그래프 바닥에서 목표선까지의 거리다 — 호출부가 자기 축 계산으로
/// 넘긴다. 목표가 축 밖이면(0 이하거나 최댓값을 넘으면) 아무것도 그리지 않는다.
///
/// **선만 긋는다.** 목표치는 그래프 왼쪽 [ChartGoalAxis] 칸이 적는다 — 선 위
/// 오른쪽 끝에 얹던 시절에는 그래프마다 라벨이 다른 자리에 앉았고, 목표 근처의
/// 막대 꼭대기와 겹쳤다. (#1071)
class GoalLineOverlay extends StatelessWidget {
  const GoalLineOverlay({super.key, required this.bottom, this.visible = true});

  final double bottom;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: const IgnorePointer(
        child: CustomPaint(
          painter: _GoalLinePainter(),
          // 선 자체는 높이가 없다. 칸만 잡아 둔다.
          child: SizedBox(height: 0, width: double.infinity),
        ),
      ),
    );
  }
}

class _GoalLinePainter extends CustomPainter {
  const _GoalLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    ChartGoalLine.paint(canvas, y: 0, left: 0, right: size.width);
  }

  @override
  bool shouldRepaint(_GoalLinePainter old) => false;
}

/// 그래프 왼쪽의 목표치 칸. **모든 그래프가 이 칸 하나로 목표치를 적는다.**
///
/// 홈 탭 식단 영양 그래프가 쓰던 배치를 그대로 옮겼다 — 폭은 눈금 라벨이 쓰던
/// 38(글씨 배율을 따라간다), 라벨은 목표선 높이에 맞춰 오른쪽 정렬 두 줄
/// (`목표` / 목표치)로 앉는다. 한 줄로 두면 칸이 넓어져야 하는데, 그러면 360px
/// 영어 로케일에서 축 라벨 줄이 넘친다. (#1004, #1071)
///
/// 목표가 없어도 칸은 자리를 지킨다 — 지표를 바꿀 때 그래프 폭이 흔들리지
/// 않게 하려는 것이다.
class ChartGoalAxis extends StatelessWidget {
  const ChartGoalAxis({
    super.key,
    required this.height,
    this.label,
    this.lineBottom,
    this.style = defaultStyle,
  });

  /// 그래프(막대·꺾은선)가 그려지는 높이. 축 라벨 줄은 뺀 값이다.
  final double height;

  /// 두 줄 라벨 — 첫 줄 `목표`, 둘째 줄 목표치. null 이면 칸만 지킨다.
  final String? label;

  /// 그래프 바닥에서 목표선까지의 거리. null 이면 라벨을 앉히지 않는다.
  final double? lineBottom;

  /// 글씨 모양. 자리와 두 줄 구성은 모든 그래프가 같지만, 색·굵기는 각 화면이
  /// 쓰던 값을 그대로 둔다. (#1071)
  final TextStyle style;

  static const TextStyle defaultStyle = TextStyle(
    fontSize: ChartGoalLine.labelFontSize,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: ChartGoalLine.color,
  );

  @override
  Widget build(BuildContext context) {
    // 칸도 글씨 배율을 따라간다 (#1004). 상수로 박아 두면 배율이 올라간 순간
    // `목표` 아래 줄이 상자에 눌려 반만 보인다.
    final TextScaler ts = MediaQuery.textScalerOf(context);
    final double width = chartGoalAxisWidth * ts.scale(1);
    final double labelHeight = ts.scale(style.fontSize ?? 10) * 1.35 * 2;
    final double? bottom = lineBottom;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          if (label != null && bottom != null)
            Positioned(
              right: 0,
              top: (height - bottom - labelHeight / 2).clamp(
                0.0,
                math.max(0, height - labelHeight),
              ),
              child: SizedBox(
                key: chartGoalLabelKey,
                height: labelHeight,
                child: Center(
                  child: Text(
                    label!,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    style: style,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 목표치 칸의 폭(글씨 배율 1 기준).
const double chartGoalAxisWidth = 38;

/// 목표치 라벨을 집는 키. 화면마다 그래프가 여러 개면 여러 번 나온다.
const Key chartGoalLabelKey = ValueKey<String>('chart-goal-label');

/// 그래프와 목표치 칸 사이 간격.
const double chartGoalAxisGap = 6;
