import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/typography.dart';

/// Builds the trainer app's [ThemeData] from the design tokens. Light
/// mode only for now — dark mode follows the same shape in a later phase.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      // 두 앱 공통 한글 UI 서체 (#995). pubspec 의 Pretendard 패밀리를
      // 앱 전역 기본으로 둔다 — 화면에서 fontFamily 를 따로 지정하지 않는다.
      fontFamily: AppTypography.fontFamily,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        onSecondary: AppColors.accentForeground,
        onSurface: AppColors.cardForeground,
        error: AppColors.destructive,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(AppRadius.md),
      borderSide: BorderSide(color: AppColors.borderStrong),
    );

    return base.copyWith(
      textTheme: AppTypography.buildTextTheme(base.textTheme),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(
          color: AppColors.subtleForeground,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: AppColors.mutedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
          borderSide: BorderSide(color: AppColors.destructive),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.card),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.secondary,
        contentTextStyle: TextStyle(
          color: AppColors.primaryForeground,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.all(AppRadius.sm),
        ),
        textStyle: TextStyle(
          color: AppColors.primaryForeground,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
        ),
      ),
      // Material 3 기본 윤곽선은 화면 곳곳에서 유일하게 짙은 색으로
      // 튀었다 — 다른 요소(입력창·다이얼로그·칩)는 전부 이 팔레트의
      // 옅은 톤을 쓰는데 `OutlinedButton`만 테마를 안 받고 있었다.
      // 화면마다 손으로 고치는 대신 여기 한 곳에서 앱 전역에 적용한다.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mutedForeground,
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
    );
  }
}
