import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/design_system/tokens/typography.dart';

/// 화면 아래에 잠깐 떴다 사라지는 알림(토스트)의 생김새.
///
/// 값을 테마와 [showAppToast] 헬퍼가 함께 보므로 여기 한 곳에 둔다 — 헬퍼를
/// 거치지 않고 `showSnackBar` 를 직접 부른 자리도 같은 모습으로 뜬다.
class AppToastStyle {
  AppToastStyle._();

  /// 토스트 바탕. 카드 위에 떠 있는 것이 분명해야 해서 본문 잉크색을 쓴다.
  static const Color background = AppColors.foreground;

  static const Color foreground = Color(0xFFFFFFFF);

  /// 어두운 바탕 위에서 읽히는 밝은 브랜드색. [AppColors.primary] 는 이
  /// 바탕에서 너무 가라앉아 동작 버튼 글자로 쓸 수 없다.
  static const Color actionText = Color(0xFF7FD0F0);

  /// 아이콘 색 세 가지. **바탕색은 종류와 무관하게 하나로 둔다** — 성공과
  /// 실패의 바탕까지 다르면 두 토스트가 서로 다른 부품처럼 보인다.
  static const Color successIcon = Color(0xFF4CD9B0);
  static const Color errorIcon = Color(0xFFFF8A8A);
  static const Color infoIcon = Color(0xFF7FD0F0);

  static const double maxWidth = 560;

  /// 토스트가 상태바 아래에서 떨어지는 거리.
  static const double topGap = AppSpacing.md;

  /// 헬퍼를 거치지 않은 `SnackBar` 이 화면 아래 끝(또는 하단 내비게이션 바)에서
  /// 떨어지는 거리. 앱이 띄우는 알림은 [showAppToast] 로 위쪽에 뜨고, 이 값은
  /// 그 그물에만 쓰인다.
  static const double bottomGap = AppSpacing.md;

  static const Duration enterDuration = Duration(milliseconds: 220);

  static const Duration exitDuration = Duration(milliseconds: 180);

  static const Duration duration = Duration(seconds: 2);

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
}
