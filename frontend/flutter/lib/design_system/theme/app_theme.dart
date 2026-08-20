import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/typography.dart';

/// Builds the app-wide `ThemeData`. The light scheme is hand-mapped from
/// the original prototype's `theme.css` so the look matches 1:1; dark
/// mode falls back to a derived ColorScheme.fromSeed for now and will
/// be tightened in a later phase.
class AppTheme {
  AppTheme._();

  /// Material 3 caps modal bottom sheets at 640dp by default, so an inner
  /// `ConstrainedBox` alone can never widen them. Lifting the route-level
  /// cap to [AppBreakpoints.contentMaxWidth] lets sheets reach the same
  /// width as the tab pages on wide viewports; their own inner constraints
  /// then centre the content.
  static const BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
    constraints: BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
  );

  /// 대화상자 배경을 **카드와 같은 흰색**으로 고정한다. (#925)
  ///
  /// Material 3 의 `AlertDialog` 는 배경을 `ColorScheme.surfaceContainerHigh`
  /// 에서 가져오는데, 이 앱은 그 자리에 `AppColors.accent`(연한 파랑)를 두었다.
  /// accent 는 **카드 안에서 한 덩이를 구분하려고** 쓰는 색이라, 창 전체를 그
  /// 색으로 칠하면 대화상자가 카드 위에 뜬 또 하나의 알약처럼 보이고 그 안에
  /// 다시 흰 요소를 얹을 수 없다. 대화상자는 카드와 같은 층위의 표면이므로 같은
  /// 색이 맞다.
  ///
  /// `surfaceContainerHigh` 자체는 건드리지 않는다 — 목록 행·알약처럼 그 색을
  /// 의도해서 쓰는 자리까지 함께 바뀐다.
  static const DialogThemeData _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.card,
  );

  static ThemeData light() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      primaryContainer: AppColors.accent,
      onPrimaryContainer: AppColors.accentForeground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
      secondaryContainer: AppColors.accent,
      onSecondaryContainer: AppColors.accentForeground,
      tertiary: AppColors.secondary,
      onTertiary: AppColors.secondaryForeground,
      error: AppColors.destructive,
      onError: AppColors.destructiveForeground,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: AppColors.destructive,
      surface: AppColors.background,
      onSurface: AppColors.foreground,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.inputBackground,
      surfaceContainerHigh: AppColors.accent,
      surfaceContainerHighest: AppColors.muted,
      onSurfaceVariant: AppColors.mutedForeground,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      surfaceTint: AppColors.primary,
      inverseSurface: AppColors.foreground,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.accent,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    final base = ThemeData(
      useMaterial3: true,
      // 두 앱 공통 한글 UI 서체 (#995). pubspec 의 Pretendard 패밀리를
      // 앱 전역 기본으로 둔다 — 화면에서 fontFamily 를 따로 지정하지 않는다.
      fontFamily: AppTypography.fontFamily,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
    return base.copyWith(
      textTheme: AppTypography.buildTextTheme(base.textTheme),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      dialogTheme: _dialogTheme,
      bottomSheetTheme: _bottomSheetTheme,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    final base = ThemeData(
      useMaterial3: true,
      // 두 앱 공통 한글 UI 서체 (#995). pubspec 의 Pretendard 패밀리를
      // 앱 전역 기본으로 둔다 — 화면에서 fontFamily 를 따로 지정하지 않는다.
      fontFamily: AppTypography.fontFamily,
      brightness: Brightness.dark,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
    return base.copyWith(
      textTheme: AppTypography.buildTextTheme(base.textTheme),
      bottomSheetTheme: _bottomSheetTheme,
    );
  }
}
