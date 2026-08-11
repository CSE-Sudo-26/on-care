import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/typography.dart';

void main() {
  test('본문과 라벨 타이포그래피는 웹 콘솔 가독성 기준을 유지한다', () {
    final textTheme = AppTypography.buildTextTheme(
      ThemeData(useMaterial3: true).textTheme,
    );

    expect(textTheme.bodyLarge!.fontSize, 17);
    expect(textTheme.bodyMedium!.fontSize, 16);
    expect(textTheme.bodySmall!.fontSize, 14);
    expect(textTheme.labelLarge!.fontSize, 16);
    expect(textTheme.labelMedium!.fontSize, 14);
    expect(textTheme.labelSmall!.fontSize, 13);
  });

  test('회색 텍스트 토큰은 흰 배경에서 의도한 대비를 유지한다', () {
    expect(_contrast(AppColors.mutedForeground, Colors.white), greaterThan(7));
    expect(
      _contrast(AppColors.subtleForeground, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.disabledForeground, Colors.white),
      greaterThanOrEqualTo(3),
    );
  });
}

double _contrast(Color first, Color second) {
  final lighter = math.max(_luminance(first), _luminance(second));
  final darker = math.min(_luminance(first), _luminance(second));
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color color) {
  final argb = color.toARGB32();
  final channels = <int>[(argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff];
  final linear = channels.map((channel) {
    final value = channel / 255;
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }).toList();
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}
