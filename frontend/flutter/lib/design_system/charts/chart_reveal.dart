import 'package:flutter/material.dart';

import 'package:oncare/design_system/tokens/motion.dart';

/// Builder signature for [ChartReveal]. [t] runs 0 → 1 over the reveal.
typedef ChartRevealBuilder = Widget Function(BuildContext context, double t);

/// Drives a one-shot 0 → 1 progress value for chart entry animations: bars
/// grow up from the baseline, donuts sweep around the circle, lines draw
/// left-to-right.
///
/// Pass [replayKey] when a control (period toggle, metric tab) swaps the
/// underlying data — the reveal restarts so the new numbers register as a
/// change instead of a silent redraw. Leave it null for charts whose data
/// only arrives once.
///
/// When the platform asks for reduced motion the builder is called once with
/// `t = 1`, so the chart renders in its final state with no animation. Widget
/// tests get the same treatment via `MediaQuery(disableAnimations: true)`.
class ChartReveal extends StatelessWidget {
  const ChartReveal({
    required this.builder,
    this.duration = AppMotion.chartDraw,
    this.curve = AppMotion.chartCurve,
    this.replayKey,
    super.key,
  });

  final ChartRevealBuilder builder;
  final Duration duration;

  /// Applied to [t] before it reaches the builder. Staggered charts should
  /// pass [Curves.linear] here and let [chartStagger] ease each item instead,
  /// otherwise the curve gets applied twice.
  final Curve curve;

  final Object? replayKey;

  /// A NaN key never equals itself, so it would rebuild — and therefore
  /// restart — the tween on every frame, leaving the chart stuck at 0. Callers
  /// pass ratios here, so fold any non-finite double onto one stable sentinel.
  Object? get _stableReplayKey {
    final Object? k = replayKey;
    if (k is double && !k.isFinite) return '_nonFinite';
    return k;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return builder(context, 1);
    }
    final Object? key = _stableReplayKey;
    return TweenAnimationBuilder<double>(
      // Rebuilding under a new key restarts the tween from 0.
      key: key == null ? null : ValueKey<Object>(key),
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (BuildContext context, double t, Widget? _) =>
          builder(context, t),
    );
  }
}

/// Slices a linear master progress [t] into a per-item window so a bar chart
/// ripples across the axis instead of every bar rising at once.
///
/// Item [index] of [count] starts once the earlier items are underway and
/// then runs its own eased 0 → 1. Feed this the raw progress from a
/// [ChartReveal] built with [Curves.linear].
///
/// The result is clamped to 0..1 — painters multiply it into bar heights and
/// pass it straight to `Color.withValues(alpha:)`, which asserts on values
/// outside that range, so an overshooting [curve] must not leak through.
double chartStagger(
  double t,
  int index,
  int count, {
  double spread = AppMotion.barStagger,
  Curve curve = AppMotion.chartCurve,
}) {
  final double clamped = t.clamp(0.0, 1.0);
  final double span = 1 - spread;
  if (count <= 1 || spread <= 0 || span <= 0) {
    return curve.transform(clamped).clamp(0.0, 1.0);
  }
  final double start = (spread / (count - 1)) * index;
  final double local = ((clamped - start) / span).clamp(0.0, 1.0);
  return curve.transform(local).clamp(0.0, 1.0);
}
