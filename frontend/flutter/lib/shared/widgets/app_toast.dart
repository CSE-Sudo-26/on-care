import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/design_system/tokens/toast.dart';

/// 토스트가 전하는 소식의 종류.
///
/// 아이콘과 머무는 시간만 달라진다 — 바탕색까지 갈라 놓으면 성공 토스트와
/// 실패 토스트가 같은 앱의 같은 부품으로 보이지 않는다.
enum AppToastKind { info, success, error }

/// 화면 아래에 잠깐 뜨는 알림을 띄운다. (#1259)
///
/// 앱의 모든 "저장했어요 / 실패했어요" 는 이 함수 하나를 거친다. 예전에는
/// 호출부마다 `showSnackBar` 를 직접 불러 아이콘도 머무는 시간도 제각각이었고,
/// MY 의 건강 목표 저장만 위쪽 배너로 따로 떠 있었다.
///
/// 화면을 닫은 **뒤에** 결과가 도착하는 자리(시트를 pop 하고 저장 응답을
/// 기다리는 흐름)에서는 [showAppToastVia] 에 미리 잡아 둔
/// `ScaffoldMessengerState` 를 넘긴다 — 사라진 화면의 `BuildContext` 로는
/// 토스트를 띄울 수 없다.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  BuildContext context,
  String message, {
  AppToastKind kind = AppToastKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  return showAppToastVia(
    ScaffoldMessenger.of(context),
    message,
    kind: kind,
    action: action,
    duration: duration,
  );
}

/// [showAppToast] 와 같지만 미리 잡아 둔 messenger 로 띄운다.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToastVia(
  ScaffoldMessengerState messenger,
  String message, {
  AppToastKind kind = AppToastKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  // 앞의 토스트가 사라지기를 기다리지 않는다. 사용자가 빠르게 두 번 저장하면
  // 뒤늦게 뜨는 첫 토스트는 이미 지난 소식이다.
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    buildAppToast(
      messenger.context,
      message,
      kind: kind,
      action: action,
      duration: duration,
    ),
  );
}

/// 토스트 위젯 자체. 테스트와 골든에서 직접 만들어 볼 수 있게 열어 둔다.
@visibleForTesting
SnackBar buildAppToast(
  BuildContext context,
  String message, {
  AppToastKind kind = AppToastKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  // 넓은 화면에서 토스트가 창 끝까지 늘어나면 한 줄 문구가 가운데를 지나
  // 흩어진다. 본문과 같은 방식으로 폭을 묶고 가운데로 모은다.
  final double screenWidth = MediaQuery.maybeSizeOf(context)?.width ?? 0;
  final double sideMargin = math.max(
    AppSpacing.lg,
    (screenWidth - AppToastStyle.maxWidth) / 2,
  );
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.fromLTRB(
      sideMargin,
      0,
      sideMargin,
      AppToastStyle.bottomGap,
    ),
    duration:
        duration ??
        (kind == AppToastKind.error
            ? AppToastStyle.errorDuration
            : AppToastStyle.duration),
    action: action,
    // 폭은 바깥 여백이 정한다(`MainAxisSize.max`). 내용만큼만 줄이면 긴 문구가
    // 좁은 기둥으로 접혀 네 줄이 되고, 알림 길이에 따라 알약 폭이 들쭉날쭉해진다.
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(_icon(kind), size: 20, color: _iconColor(kind)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

IconData _icon(AppToastKind kind) {
  switch (kind) {
    case AppToastKind.success:
      return Icons.check_circle_rounded;
    case AppToastKind.error:
      return Icons.error_rounded;
    case AppToastKind.info:
      return Icons.info_rounded;
  }
}

Color _iconColor(AppToastKind kind) {
  switch (kind) {
    case AppToastKind.success:
      return AppToastStyle.successIcon;
    case AppToastKind.error:
      return AppToastStyle.errorIcon;
    case AppToastKind.info:
      return AppToastStyle.infoIcon;
  }
}
