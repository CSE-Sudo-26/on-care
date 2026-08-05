import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// A compact labelled bar series (주간 이행률, 세션 수 …).
///
/// Deliberately hand-built rather than pulled from a charting package:
/// the console needs exactly two chart shapes (this and [Sparkline]),
/// both trivial, and a chart library would add build weight and its own
/// theming surface for no gain. If a real analytics screen ever needs
/// axes, tooltips and zoom, that's the moment to add one.
class BarSeriesChart extends StatelessWidget {
  /// Creates a bar series.
  const BarSeriesChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 96,
    this.maxValue,
    this.highlightIndex,
    this.overThreshold,
    this.valueSuffix = '',
    this.showValues = false,
    this.pendingFromIndex,
  }) : assert(values.length == labels.length, 'values/labels 길이가 달라요');

  /// Bar values (non-negative).
  final List<int> values;

  /// X-axis labels, one per value.
  final List<String> labels;

  /// Plot height (excluding labels).
  final double height;

  /// Scale ceiling. Defaults to the largest value (min 1).
  final int? maxValue;

  /// Bar rendered in the strong primary fill (e.g. 오늘).
  final int? highlightIndex;

  /// Values strictly above this render in the warning colour.
  final int? overThreshold;

  /// Appended to the value label when [showValues] is on.
  final String valueSuffix;

  /// Whether to print the value above each bar.
  final bool showValues;

  /// First index that hasn't happened yet (e.g. tomorrow, in a Mon–Sun
  /// chart shown on Thursday). Those bars render as an empty track with
  /// no value, so a day with no data yet can't be misread as a zero.
  final int? pendingFromIndex;

  @override
  Widget build(BuildContext context) {
    final pendingFrom = pendingFromIndex ?? values.length;
    final ceiling = <int>[
      maxValue ?? 0,
      if (values.isNotEmpty) values.reduce((a, b) => a > b ? a : b),
      1,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _Bar(
                      value: i >= pendingFrom ? 0 : values[i],
                      ceiling: ceiling,
                      color: _colorFor(i),
                      label: showValues && i < pendingFrom
                          ? '${values[i]}$valueSuffix'
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: highlightIndex == i
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: highlightIndex == i
                        ? AppColors.primary
                        : i >= pendingFrom
                        ? AppColors.disabledForeground
                        : AppColors.subtleForeground,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _colorFor(int index) {
    if (overThreshold != null && values[index] > overThreshold!) {
      return AppColors.overTarget;
    }
    if (highlightIndex == index) return AppColors.primary;
    return AppColors.aiCardGradientEnd;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.ceiling,
    required this.color,
    required this.label,
  });

  final int value;
  final int ceiling;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    // A zero value still draws a 2px stub so the day reads as "recorded,
    // nothing done" rather than "no data".
    final ratio = (value / ceiling).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelHeight = label == null ? 0.0 : 14.0;
        final plot = (constraints.maxHeight - labelHeight).clamp(
          0.0,
          constraints.maxHeight,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (label != null)
              SizedBox(
                height: labelHeight,
                child: FittedBox(
                  child: Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            Container(
              height: (plot * ratio).clamp(2.0, plot),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: AppRadius.xs),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A small trend line with an optional threshold rule (7일 나트륨 추이).
class Sparkline extends StatelessWidget {
  /// Creates a sparkline.
  const Sparkline({
    super.key,
    required this.values,
    this.threshold,
    this.height = 44,
    this.color = AppColors.primary,
  });

  /// Series, oldest → newest.
  final List<int> values;

  /// Optional horizontal rule (e.g. the daily sodium target).
  final int? threshold;

  /// Plot height.
  final double height;

  /// Line colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            '데이터가 아직 부족해요',
            style: TextStyle(fontSize: 11, color: AppColors.subtleForeground),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          threshold: threshold,
          color: color,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.threshold,
    required this.color,
  });

  final List<int> values;
  final int? threshold;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = <int>[
      values.reduce((a, b) => a > b ? a : b),
      threshold ?? 0,
      1,
    ].reduce((a, b) => a > b ? a : b).toDouble();
    // Head-room so the peak point's dot isn't clipped by the top edge.
    final ceiling = maxV * 1.15;
    final dx = size.width / (values.length - 1);

    double yFor(num v) => size.height - (v / ceiling) * size.height;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++) Offset(i * dx, yFor(values[i])),
    ];

    // Area fill under the line.
    final area = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.10));

    if (threshold != null) {
      final y = yFor(threshold!);
      final dash = Paint()
        ..color = AppColors.overTarget.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y), dash);
      }
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots: over-threshold points flip to the warning colour so the
    // "which days went over" question is answered without a legend.
    for (var i = 0; i < points.length; i++) {
      final over = threshold != null && values[i] > threshold!;
      canvas.drawCircle(
        points[i],
        over ? 3 : 2,
        Paint()..color = over ? AppColors.overTarget : color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.threshold != threshold || old.color != color;
}
