import 'package:flutter/material.dart';

/// Typography token wrapper. Adjusts a base [TextTheme] to the trainer
/// app's type scale (weights tuned to match the Figma mock's headings /
/// body text). Keeps the same shape as the user app for consistency.
class AppTypography {
  AppTypography._();

  /// 두 앱 공통 서체. pubspec 의 `fonts:` 패밀리 이름과 같아야 한다.
  static const String fontFamily = 'Pretendard';

  /// 앱 전체 글씨 배율 (#995). 사용자앱과 같은 장치를 트레이너 콘솔에도 둔다.
  /// 하드코딩된 `fontSize:` 까지 함께 곱해지므로 화면 파일을 건드리지 않는다.
  static const double textScale = 1.10;

  /// 기기 설정을 존중하면서 [textScale] 을 **바닥값**으로 얹는다.
  ///
  /// 곱하지 않고 `max` 를 쓴다. 곱하면 접근성 배율 1.3 을 켠 기기에서 1.43 이
  /// 되어, 레이아웃이 실제로 버티는 상한(1.3)을 넘긴다. 기본값을 키우는 것이
  /// 목적이므로 기기가 이미 더 크게 쓰고 있으면 그 값을 그대로 둔다.
  static TextScaler scaler(TextScaler deviceScaler) {
    final double device = deviceScaler.scale(1);
    return TextScaler.linear(device > textScale ? device : textScale);
  }

  static TextTheme buildTextTheme(TextTheme base) {
    // 사용자 앱(design_system/tokens/typography.dart)의 크기·가중치
    // 스케일과 일치시킨다. Material 기본 bodyMedium(14px)은 정보가 많은
    // 데스크톱 콘솔에서 작으므로 본문 기준을 16px로 둔다.
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 33,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 16, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(fontSize: 15, height: 1.45),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(fontSize: 15),
      labelSmall: base.labelSmall?.copyWith(fontSize: 14),
    );
  }
}
