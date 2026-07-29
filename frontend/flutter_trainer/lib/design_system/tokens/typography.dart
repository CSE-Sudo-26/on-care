import 'package:flutter/material.dart';

/// Typography token wrapper. Adjusts a base [TextTheme] to the trainer
/// app's type scale (weights tuned to match the Figma mock's headings /
/// body text). Keeps the same shape as the user app for consistency.
class AppTypography {
  AppTypography._();

  static TextTheme buildTextTheme(TextTheme base) {
    // 사용자 앱(design_system/tokens/typography.dart)의 가중치 스케일과 일치.
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
