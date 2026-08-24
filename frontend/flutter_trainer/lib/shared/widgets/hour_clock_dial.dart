import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';

/// 1~12가 원형으로 둘러선 시계 다이얼 — 눌러서 시(時)를 고른다.
///
/// 분은 이 다이얼이 정하지 않는다(#1247·#1250에서 붙인 옆 숫자 입력이
/// 정한다) — 두 다이얼(시작·종료)이 한 화면에 동시에 보이므로, 각각
/// 시/분을 다 고르는 기존 Material `TimePicker` 두 벌을 그대로 넣으면
/// 자리와 손동작이 두 배로 늘어난다. 시는 다이얼로 훑어 고르고, 분은
/// 숫자로 정확히 적는 편이 이 화면에 맞다.
class HourClockDial extends StatelessWidget {
  const HourClockDial({
    required this.hour12,
    required this.onChanged,
    this.keyPrefix = 'hour-dial',
    this.size = 220,
    super.key,
  });

  /// 1..12.
  final int hour12;
  final ValueChanged<int> onChanged;
  final String keyPrefix;
  final double size;

  @override
  Widget build(BuildContext context) {
    final center = size / 2;
    final numberRadius = size / 2 - 22;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: AppColors.borderStrong),
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _ClockHandPainter(
              hour12: hour12,
              numberRadius: numberRadius,
              center: center,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
          ),
          for (var h = 1; h <= 12; h++) _numberButton(h, center, numberRadius),
        ],
      ),
    );
  }

  Widget _numberButton(int h, double center, double radius) {
    // 12시가 정각 위(-90도), 시계 방향으로 한 시간마다 30도.
    final angle = (h % 12) * 30 * (math.pi / 180) - math.pi / 2;
    final x = center + radius * math.cos(angle);
    final y = center + radius * math.sin(angle);
    final selected = h == hour12;
    return Positioned(
      left: x - 18,
      top: y - 18,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$h시',
        child: InkWell(
          key: ValueKey<String>('$keyPrefix-$h'),
          onTap: () => onChanged(h),
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.accent : Colors.transparent,
            ),
            child: Text(
              '$h',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primaryForeground
                    : AppColors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockHandPainter extends CustomPainter {
  _ClockHandPainter({
    required this.hour12,
    required this.numberRadius,
    required this.center,
  });

  final int hour12;
  final double numberRadius;
  final double center;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = (hour12 % 12) * 30 * (math.pi / 180) - math.pi / 2;
    // 숫자 자리 바로 앞까지만 — 숫자 원 위로 겹치지 않는다.
    final handLength = numberRadius - 20;
    final end = Offset(
      center + handLength * math.cos(angle),
      center + handLength * math.sin(angle),
    );
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center, center), end, paint);
  }

  @override
  bool shouldRepaint(_ClockHandPainter oldDelegate) =>
      oldDelegate.hour12 != hour12;
}
