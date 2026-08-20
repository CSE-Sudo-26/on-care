import 'package:flutter/material.dart';

/// Typography token wrapper. Adjusts a base `TextTheme` to the Oncare
/// type scale defined in docs/DESIGN_TOKENS.md §2.
class AppTypography {
  AppTypography._();

  /// 두 앱 공통 서체. pubspec 의 `fonts:` 패밀리 이름과 같아야 한다.
  static const String fontFamily = 'Pretendard';

  /// 앱 전체 글씨 배율 (#995).
  ///
  /// 화면 위젯 상당수가 `fontSize:` 를 직접 박아 두어서 타입 스케일만 키우면
  /// 대부분의 글씨가 그대로 남는다. 배율은 렌더 시점에 **하드코딩된 크기까지**
  /// 함께 곱해지므로, 한 곳만 고쳐 전 화면에 걸린다. 파트별 작업 파일을
  /// 건드리지 않는 것도 이 방식을 고른 이유다.
  ///
  /// 기기 접근성 설정 위에 곱해진다 — 값을 올릴 때는 폰 기준으로 잘림을
  /// 확인한다.
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
      labelMedium: base.labelMedium?.copyWith(fontSize: 14),
      labelSmall: base.labelSmall?.copyWith(fontSize: 13),
    );
  }
}
