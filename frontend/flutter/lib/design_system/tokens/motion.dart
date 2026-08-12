import 'package:flutter/animation.dart';

/// Motion tokens. Keeping durations and curves here stops each chart from
/// inventing its own timing — the whole dashboard should feel like one
/// coordinated reveal, not five widgets racing each other.
class AppMotion {
  AppMotion._();

  /// Charts that draw along a path (donut sweep, trend line) — long enough
  /// to read as "being drawn", short enough not to delay the screen.
  static const Duration chartDraw = Duration(milliseconds: 750);

  /// Bar charts. Slightly longer because the per-bar stagger eats into the
  /// time any single bar actually spends growing.
  static const Duration chartGrow = Duration(milliseconds: 850);

  /// Small inline meters (nutrition progress bars) — these sit next to text,
  /// so they should settle before the eye moves on.
  static const Duration meterFill = Duration(milliseconds: 600);

  /// Decelerating curve: values shoot out from zero, then ease into place.
  static const Curve chartCurve = Curves.easeOutCubic;

  /// How much of a staggered chart's timeline is spent handing off between
  /// items. 0 = every bar grows in lockstep, 1 = strictly one after another.
  static const double barStagger = 0.45;
}
