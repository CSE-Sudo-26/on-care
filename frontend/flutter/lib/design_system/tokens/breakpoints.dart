import 'package:flutter/widgets.dart';

/// Width thresholds matching docs/DESIGN_TOKENS.md §7.
class AppBreakpoints {
  AppBreakpoints._();
  static const double tablet = 600;
  static const double desktop = 1024;

  /// Max width of primary page/sheet content. The tab pages and every
  /// bottom-sheet cap their content at this so they scale with the
  /// viewport identically instead of drifting apart.
  static const double contentMaxWidth = 720;
}

/// Coarse device form factor inferred from a width. Pages and shells
/// switch layout based on this (e.g. NavigationBar on mobile vs
/// NavigationRail on tablet/desktop in later phases).
enum DeviceForm { mobile, tablet, desktop }

extension AppDeviceFormX on BuildContext {
  DeviceForm get deviceForm {
    final w = MediaQuery.sizeOf(this).width;
    if (w >= AppBreakpoints.desktop) return DeviceForm.desktop;
    if (w >= AppBreakpoints.tablet) return DeviceForm.tablet;
    return DeviceForm.mobile;
  }

  bool get isMobile => deviceForm == DeviceForm.mobile;
  bool get isTablet => deviceForm == DeviceForm.tablet;
  bool get isDesktop => deviceForm == DeviceForm.desktop;
}
