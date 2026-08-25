import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/typography.dart';

/// 화면 위에 잠깐 떴다 사라지는 알림(토스트)의 생김새.
///
/// 사용자 앱의 `AppToastStyle`(#1259)과 같은 모양이다 — 콘솔도 같은 이유로
/// `SnackBar`가 아니라 루트 오버레이를 쓴다: 리포트 전송처럼 대화상자나 시트
/// 위에서 결과를 알려야 하는 자리가 있어, `Scaffold` 안에만 그려지는
/// `SnackBar`로는 가려질 수 있다.
class AppToastStyle {
  AppToastStyle._();

  /// 트레이너 앱의 기존 `SnackBarThemeData.backgroundColor`와 같은 남색이다
  /// — 위치만 위로 옮기는 것이지, 알림의 브랜드 색까지 검정으로 바꾸는 게
  /// 아니다.
  static const Color background = AppColors.secondary;

  static const Color foreground = Color(0xFFFFFFFF);

  /// 어두운 바탕 위에서 읽히는 밝은 강조색. [AppColors.primary]는 이 바탕에서
  /// 너무 가라앉아 동작 버튼 글자로 쓸 수 없다.
  static const Color actionText = Color(0xFF7FD0F0);

  static const Color successIcon = Color(0xFF4CD9B0);
  static const Color errorIcon = Color(0xFFFF8A8A);
  static const Color infoIcon = Color(0xFF7FD0F0);

  static const double maxWidth = 560;

  /// 토스트가 상태바 아래에서 떨어지는 거리.
  static const double topGap = AppSpacing.md;

  static const Duration enterDuration = Duration(milliseconds: 220);

  static const Duration exitDuration = Duration(milliseconds: 180);

  static const Duration duration = Duration(seconds: 2);

  /// 동작 버튼이 있는 토스트는 눌러 볼 시간을 더 준다.
  static const Duration actionDuration = Duration(seconds: 4);

  /// 실패는 사용자가 다시 시도할지 정해야 하므로 조금 더 머문다.
  static const Duration errorDuration = Duration(milliseconds: 3500);

  static const BorderRadius borderRadius = BorderRadius.all(AppRadius.lg);

  static const TextStyle contentTextStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    color: foreground,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle actionTextStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    color: actionText,
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
  );
}
