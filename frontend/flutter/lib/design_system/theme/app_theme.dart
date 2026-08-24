import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/design_system/tokens/toast.dart';
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

  /// 날짜 선택 다이얼로그는 **흰 바탕**이다.
  ///
  /// Material 3 은 달력의 바탕으로 `surfaceContainerHigh` 를 쓰는데, 이 앱에서
  /// 그 자리는 브랜드 하늘색(`AppColors.accent`)이다. 그래서 식단·운동·일정 등
  /// 날짜를 고르는 모든 창이 옅은 파랑으로 깔려, 정작 그 창을 띄운 흰 카드·시트와
  /// 따로 놀았다. 다른 다이얼로그([_dialogTheme])와 같은 흰색으로 맞춘다.
  ///
  /// `surfaceTintColor` 를 투명으로 두는 것까지가 한 벌이다 — 비워 두면 M3 가
  /// 높이에 따라 브랜드 색을 다시 얹어 흰색이 미묘하게 물든다.
  static const DatePickerThemeData _datePickerTheme = DatePickerThemeData(
    backgroundColor: AppColors.card,
    headerBackgroundColor: AppColors.card,
    headerForegroundColor: AppColors.foreground,
    surfaceTintColor: Colors.transparent,
  );

  /// `SnackBar` 을 **떠 있는 형태**로 고정한다. (#1259)
  ///
  /// 앱이 띄우는 알림은 [showAppToast] 로 화면 위쪽 오버레이에 뜬다. 이 테마는
  /// 그 헬퍼를 거치지 않은 `showSnackBar` 호출을 위한 **그물**이다 — 기본값
  /// 그대로 두면 아래에서 `+` 버튼과 겹치기 때문이다.
  ///
  /// Material 기본값(`SnackBarBehavior.fixed`)은 토스트를 하단 내비게이션 바
  /// 위에 각진 채로 붙인다. 그런데 이 앱의 `+` 버튼은 `Scaffold` 의 FAB 이
  /// 아니라 **바 위젯 안**에 들어 있어(`AppNavMetrics.addButtonLift` 만큼 솟은
  /// 투명 여백에 얹혀 있다), 붙어 버린 토스트 아래로 그 투명한 띠가 남고 `+`
  /// 원이 경계에 걸쳐 위치가 어긋나 보였다.
  ///
  /// 떠 있는 형태는 바 위젯 **전체**(= `+` 버튼까지)를 비켜서 놓이므로 셸 안팎
  /// 어디서 띄우든 자리가 맞는다 — 하단 바가 없는 로그인·온보딩 화면에서는
  /// 화면 아래 끝에서 [AppToastStyle.bottomGap] 만큼만 떨어진다.
  static const SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppToastStyle.background,
    contentTextStyle: AppToastStyle.contentTextStyle,
    actionTextColor: AppToastStyle.actionText,
    closeIconColor: AppToastStyle.foreground,
    elevation: 6,
    insetPadding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      AppToastStyle.bottomGap,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppToastStyle.borderRadius),
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
      datePickerTheme: _datePickerTheme,
      bottomSheetTheme: _bottomSheetTheme,
      snackBarTheme: _snackBarTheme,
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
      snackBarTheme: _snackBarTheme,
    );
  }
}
